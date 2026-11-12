;;; lisp/arkts-ts-mode.el --- Tree-sitter major mode for ArkTS -*- lexical-binding: t; -*-

;;; Commentary:
;; Major mode for Huawei HarmonyOS ArkTS (.ets) using tree-sitter.

;;; Code:

(require 'treesit)
(require 'typescript-ts-mode)

(defcustom arkts-ts-mode-indent-offset 2
  "Number of spaces for each indentation step in `arkts-ts-mode'."
  :type 'integer
  :safe 'integerp
  :group 'arkts)

(defun arkts-ts-mode--indent-rules ()
  "Indentation rules for `arkts-ts-mode'."
  (let ((base-rules (typescript-ts-mode--indent-rules 'arkts)))
    `((arkts
       ((parent-is "struct_body") parent-bol arkts-ts-mode-indent-offset)
       ((parent-is "arkui_children") parent-bol arkts-ts-mode-indent-offset)
       ((node-is "}") parent-bol 0)
       ,@(alist-get 'typescript base-rules)
       ,@(alist-get 'arkts base-rules)))))

;;;###autoload
(define-derived-mode arkts-ts-mode typescript-ts-base-mode "ArkTS"
  "Major mode for editing ArkTS files, powered by tree-sitter."
  :group 'arkts
  (when (treesit-ready-p 'arkts)
    (treesit-parser-create 'arkts)
    (setq-local treesit-font-lock-level (or treesit-font-lock-level 4))
    (setq-local treesit-font-lock-feature-list
                '((comment declaration)
                  (keyword string escape-sequence)
                  (constant expression identifier number pattern type)
                  (function bracket delimiter operator property variable)))
    (let* ((base-settings (typescript-ts-mode--font-lock-settings 'arkts))
           (ark-settings
            (treesit-font-lock-rules
             :language 'arkts
             :feature 'keyword
             '([ "struct" "lazy" ] @font-lock-keyword-face)

             :language 'arkts
             :feature 'type
             '((struct_declaration name: (type_identifier) @font-lock-type-face)
               (annotation_declaration name: (type_identifier) @font-lock-type-face))

             :language 'arkts
             :feature 'declaration
             '((decorator "@" @font-lock-builtin-face)
               (decorator (identifier) @font-lock-builtin-face)
               (decorator (call_expression function: (identifier) @font-lock-builtin-face)))

             :language 'arkts
             :feature 'function
             '((arkui_component_expression function: (identifier) @font-lock-type-face)
               (arkui_component_expression property: (property_identifier) @font-lock-function-call-face)))))
      (setq-local treesit-font-lock-settings (append ark-settings base-settings)))
    (setq-local treesit-simple-indent-rules (arkts-ts-mode--indent-rules))
    (treesit-major-mode-setup)))

(provide 'arkts-ts-mode)
;;; arkts-ts-mode.el ends here
