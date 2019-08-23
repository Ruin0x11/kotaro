;;; kotaro.el --- Emacs integration with kotaro        -*- lexical-binding: t; -*-

;; Copyright (C) 2019 Ruin0x11

;; Author:  <ipickering2@gmail.com>
;; Keywords: tools

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Run kotaro rewrites from Emacs.

;;; Code:

(require 'dash)
(require 'comint)
(require 'lua-mode)

(defgroup kotaro nil
  "Emacs integration with kotaro"
  :prefix "kotaro-"
  :group 'tools)

(defface kotaro-diff-added
  '((((class color) (background light))
     :background "#ddffdd"
     :foreground "#22aa22")
    (((class color) (background dark))
     :background "#335533"
     :foreground "#ddffdd"))
  "Face for lines in a diff that have been added."
  :group 'kotaro-faces)

(defface kotaro-diff-removed
 '((((class color) (background light))
    :background "#ffdddd"
    :foreground "#aa2222")
   (((class color) (background dark))
    :background "#553333"
    :foreground "#ffdddd"))
  "Face for lines in a diff that have been removed."
  :group 'kotaro-faes)

(defcustom kotaro-default-application "/home/ruin/build/work/kotaro/bin/kotaro" ; "kotaro"
  "The default location of the kotaro script.")

(defcustom kotaro-rewrite-files-dir "/home/ruin/build/work/kotaro/rewrite/"
  "Directory containing kotaro rewrite files.")

(defun kotaro--make-params-from-alist (alist)
  (-reduce-from (lambda (acc x)
                  (let* ((part (format "%s=%s" (car x) (cdr x)))
                        (pair (list "--param" part)))
                    (if acc
                        (append pair acc)
                      pair)))
                nil alist))

(defun kotaro--run-kotaro (args)
  (with-current-buffer (get-buffer-create "*kotaro*")
    (delete-region (point-min) (point-max))
    (let ((default-directory (file-name-directory
                              (directory-file-name kotaro-rewrite-files-dir))))

      (let ((result (apply 'call-process lua-default-application nil
                           (current-buffer)
                           nil
                           (append (list kotaro-default-application) args))))
        (if (equal 0 result)
            (buffer-string)
          (progn
            (error "Process kotaro returned error, see buffer %s for details" (buffer-name))))))))

(defun kotaro--run-kotaro-rewrite (rewrite-file input-files params &optional args)
  "Run kotaro rewrite with REWRITE-FILE on INPUT-FILES with PARAMS.

PARAMS is an alist with members of the form (KEY . VALUE), where
KEY and VALUE must be valid Lua identifiers.

If ARGS, a list, is passed, also pass those arguments to kotaro
unchanged.

Returns a string with the process output from running kotaro."
  (let* ((params-args (kotaro--make-params-from-alist params))
         (full-args
          (append (list "rewrite" rewrite-file)
           input-files
           params-args
           (or args '()))))
    (kotaro--run-kotaro full-args)))

(defun kotaro--parse-single-edit (edit)
  (let ((result (make-hash-table :test #'equal)))
    (if (string-match "^\\(.*?\\):\\([0-9]+\\):\\([0-9]+\\):\\(.*\\)$" edit)
        (progn
          (puthash "file" (file-truename (match-string 1 edit)) result)
          (puthash "offset" (string-to-number (match-string 2 edit)) result)
          (puthash "length" (string-to-number (match-string 3 edit)) result)
          (puthash "content" (match-string 4 edit) result)
          result)
      (error "failed to parse edit list %s" edit))))

(defun kotaro--parse-edit-list (stdout)
  (-reduce-from (lambda (acc x)
                  (let* ((file (gethash "file" x))
                         (val (gethash file acc '())))
                    (puthash file (cons x val) acc)
                    acc))
          (make-hash-table :test #'equal)
          (mapcar 'kotaro--parse-single-edit
                  (butlast (split-string stdout "\n")))))

(defun kotaro--is-lua-file (file)
  (and (file-regular-p file) (string-equal (file-name-extension file) "lua")))

(defun kotaro--pick-rewrite-file ()
  (read-file-name "Rewrite file: " kotaro-rewrite-files-dir nil t nil 'kotaro--is-lua-file))

(defun kotaro--parse-single-editor-param (line)
  (let* ((kvpairs (butlast (split-string line ";")))
         (pairs (mapcar (lambda (s) (split-string s "=")) kvpairs)))
    pairs))

(defun kotaro--parse-editor-params (stdout)
  (mapcar 'kotaro--parse-single-editor-param (butlast (split-string stdout "\n"))))

(defun kotaro--read-required-params (rewrite-file)
  "Runs kotaro to get the editor params needed for REWRITE-FILE."
  (kotaro--run-kotaro (list "rewrite" rewrite-file "--editor-params")))

(defun kotaro--read-single-param (param)
  (let* ((name (cadr (assoc "name" param)))
         (type (cadr (assoc "type" param)))
         (val (pcase type
                ("current_file" (buffer-file-name))
                ("current_line" (line-number-at-pos (point)))
                ("current_column" (current-column))
                ("string" (read-string (format "param '%s' (string): " name)))
                ("number" (read-number (format "param '%s' (number): " name)))
                ("boolean" (yes-or-no-p (format "param '%s' (boolean)" name)))
                (else (error "unknown param type '%s' (for '%s')" type name))))
         (newval (if (stringp val) val (prin1-to-string val))))
    (cons name newval)))

(defun kotaro--read-params (rewrite-file)
  (let* ((stdout (kotaro--read-required-params rewrite-file))
         (raw (kotaro--parse-editor-params stdout)))
    (mapcar 'kotaro--read-single-param raw)))

(defvar kotaro--current-edits nil "Hashmap of current edits to be applied.")

(defvar kotaro--is-editing nil)

(defvar kotaro--on-edit-decide-hook '() "Hook run when user decides to rewrite.")

(defun kotaro--clear-edits ()
  (setq kotaro--current-edits nil)
  (setq kotaro--is-editing nil)
  (kotaro--remove-edit-overlays))

(defun kotaro--get-edits-this-file ()
  (gethash (buffer-file-name) kotaro--current-edits))

(defun kotaro--rewrite-fileloop-scan ()
  (> (length (kotaro--get-edits-this-file)) 0))

(defun kotaro--delete-overlay (ov &rest _)
  "Safely delete overlay OV.
Never throws errors, and can be used in an overlay's modification-hooks."
  (ignore-errors (delete-overlay ov)))

(defun kotaro--make-overlay (l r type &rest props)
  "Place an overlay between L and R and return it.
TYPE is a symbol put on the overlay's category property.  It is used to
easily remove all overlays from a region with:
    (remove-overlays start end 'category TYPE)
PROPS is a plist of properties and values to add to the overlay."
  (let ((o (make-overlay l (or r l) (current-buffer))))
    (overlay-put o 'category type)
    (overlay-put o 'kotaro-temporary t)
    (while props (overlay-put o (pop props) (pop props)))
    (push #'kotaro--delete-overlay (overlay-get o 'modification-hooks))
    o))

(defun kotaro--edit-sort-predicate (e1 e2)
  (let ((offset1 (gethash "offset" e1))
        (offset2 (gethash "offset" e2)))
    (if (= offset1 offset2)
        (let ((length1 (gethash "length" e1))
              (length2 (gethash "length" e2)))
          (> length1 length2))
      (> offset1 offset2))))

(defsubst kotaro--unescape-string (str)
  "Unescape escaped commas, semicolons and newlines in STR."
  (replace-regexp-in-string
   "\\\\n" "\n"
   (replace-regexp-in-string
    "\\\\\\([,;]\\)" "\\1" str)))

(defun kotaro--make-edit-overlay (edit)
  (-let (((&hash "offset" "length" "content") edit))
    (kotaro--make-overlay offset (+ offset length) 'kotaro-change
                              'face 'kotaro-diff-removed
                              'before-string (propertize
                                             (kotaro--unescape-string content)
                                             'face 'kotaro-diff-added))))

(defun kotaro--display-edit-overlays (edits)
  (save-excursion
    (save-restriction
      (widen)
      (kotaro--remove-edit-overlays)
      (mapc #'kotaro--make-edit-overlay
            (sort (nreverse edits) #'kotaro--edit-sort-predicate)))))

(defun kotaro--remove-edit-overlays ()
  (remove-overlays nil nil 'kotaro-temporary t))

(defun kotaro--reindent-edit-range (edits)
  (let* ((min (-min-by (lambda (a b) (> (gethash "offset" a) (gethash "offset" b))) edits))
         (max (-max-by (lambda (a b)
                         (> (+ (gethash "offset" a) (gethash "length" a))
                          (+ (gethash "offset" b) (gethash "length" b)))) edits)))
    (indent-region
     (gethash "offset" min)
     (+ (gethash "offset" max) (gethash "length" max) 1))))

(defun kotaro--apply-edits (edits)
  ; Sort text edits so as to apply edits that modify latter parts of
  ; the document first.
  (atomic-change-group
    (mapc #'kotaro--apply-edit
          (sort (nreverse edits) #'kotaro--edit-sort-predicate))))

(defun kotaro--apply-edit (edit)
  (-let* (((&hash "offset" "length" "content") edit)
          (start offset)
          (end (+ offset length)))
    (save-excursion
      (goto-char start)
      (delete-region start end)
      (insert (kotaro--unescape-string content)))))

(defun kotaro--goto-edit-location (edit)
  (goto-char (gethash "offset" edit)))

(defun kotaro--rewrite-fileloop-operate ()
  (let ((edits (kotaro--get-edits-this-file)))
    (kotaro--goto-edit-location (car (last edits)))
    (kotaro--display-edit-overlays edits)
    (let ((result (yes-or-no-p "Continue?")))
      (kotaro--remove-edit-overlays)
      (when result (kotaro--apply-edits edits))
      result)))

(defun kotaro--start-rewrite-query (edits)
  (let ((files (hash-table-keys edits)))
    (setq kotaro--current-edits edits)
    (fileloop-initialize files 'kotaro--rewrite-fileloop-scan 'kotaro--rewrite-fileloop-operate))
  (fileloop-continue))

(defun kotaro--get-target-files (rewrite-file input-files params)
  (butlast
   (split-string
    (kotaro--run-kotaro-rewrite rewrite-file input-files params '("--editor-target-files"))
    "\n")))

(defun kotaro--save-buffer-file (file)
  (when-let ((buf (get-file-buffer file)))
    (with-current-buffer buf
      (save-buffer))))

(defun kotaro-rewrite-this-file (rewrite-file)
  (interactive (list (kotaro--pick-rewrite-file)))
  (kotaro--clear-edits)
  (let* ((params (kotaro--read-params rewrite-file))
         (our-files (list (buffer-file-name)))
         (files (kotaro--get-target-files rewrite-file our-files params)))
    ;; ensure the files on disk are updated so nothing gets out of
    ;; sync
    (mapc 'kotaro--save-buffer-file files)
    (let* ((stdout (kotaro--run-kotaro-rewrite
                    rewrite-file
                    (list (buffer-file-name))
                    params
                    '("--output-format" "edit_list")))
           (edits (kotaro--parse-edit-list stdout)))
      (kotaro--start-rewrite-query edits))))

(defun kotaro-rewrite-expression-at-point (rewrite-file)
  (interactive (list (kotaro--pick-rewrite-file)))
  (kotaro--clear-edits)
  (let* ((params (kotaro--read-params rewrite-file))
         (our-files (list (buffer-file-name)))
         (files (kotaro--get-target-files rewrite-file our-files params)))
    ;; ensure the files on disk are updated so nothing gets out of
    ;; sync
    (mapc 'kotaro--save-buffer-file files)
    (let* ((line (line-number-at-pos (point)))
           (column (current-column))
           (stdout (kotaro--run-kotaro-rewrite
                    rewrite-file
                    (list (buffer-file-name))
                    params
                    (list
                     "--output-format" "edit_list"
                     "--ast-node" (format "%s,%d,%d" "expression" line column))))
           (edits (kotaro--parse-edit-list stdout)))
      (kotaro--start-rewrite-query edits))))

(provide 'kotaro)
;;; kotaro.el ends here
