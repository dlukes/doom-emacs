;;; lang/emacs-lisp/config.el -*- lexical-binding: t; -*-

(defvar +emacs-lisp-enable-extra-fontification t
  "If non-nil, highlight special forms, and defined functions and variables.")

(defvar +emacs-lisp-outline-regexp "[ \t]*;;;;* [^ \t\n]"
  "Regexp to use for `outline-regexp' in `emacs-lisp-mode'.
This marks a foldable marker for `outline-minor-mode' in elisp buffers.")


;; `elisp-mode' is loaded at startup. In order to lazy load its config we need
;; to pretend it isn't loaded
(defer-feature! elisp-mode emacs-lisp-mode)


;;
;;; Config

(def-package! elisp-mode
  :mode ("\\.Cask\\'" . emacs-lisp-mode)
  :config
  (set-repl-handler! 'emacs-lisp-mode #'+emacs-lisp/open-repl)
  (set-eval-handler! 'emacs-lisp-mode #'+emacs-lisp-eval)
  (set-lookup-handlers! 'emacs-lisp-mode
    :definition    #'elisp-def
    :documentation #'+emacs-lisp-lookup-documentation)
  (set-docsets! 'emacs-lisp-mode "Emacs Lisp")
  (set-pretty-symbols! 'emacs-lisp-mode :lambda "lambda")
  (set-rotate-patterns! 'emacs-lisp-mode
    :symbols '(("t" "nil")
               ("let" "let*")
               ("when" "unless")
               ("advice-add" "advice-remove")
               ("add-hook" "remove-hook")
               ("add-hook!" "remove-hook!")))

  ;; TODO
  (put 'add-hook 'lisp-indent-function 'defun)

  (setq-hook! 'emacs-lisp-mode-hook
    tab-width 2
    ;; shorter name in modeline
    mode-name "Elisp"
    ;; Don't treat autoloads or sexp openers as outline headers, we have
    ;; hideshow for that.
    outline-regexp +emacs-lisp-outline-regexp)

  ;; variable-width indentation is superior in elisp
  (add-to-list 'doom-detect-indentation-excluded-modes 'emacs-lisp-mode nil #'eq)

  ;; Special indentation behavior for `add-hook'; indent like a defun block if
  ;; it contains `defun' forms and like normal otherwise.
  (defun +emacs-lisp--indent-add-hook-fn (indent-point state)
    (goto-char indent-point)
    (when (looking-at-p "\\s-*(defun ")
      (lisp-indent-defform state indent-point)))
  (put 'add-hook 'lisp-indent-function #'+emacs-lisp--indent-add-hook-fn)

  ;; Use helpful instead of describe-* from `company'
  (advice-add #'elisp--company-doc-buffer :around #'doom-use-helpful-a)

  (add-hook! 'emacs-lisp-mode-hook
    #'(outline-minor-mode
       ;; fontificiation
       rainbow-delimiters-mode
       highlight-quoted-mode
       ;; initialization
       +emacs-lisp-extend-imenu-h))

  ;; Flycheck's two emacs-lisp checkers produce a *lot* of false positives in
  ;; emacs configs, so we disable `emacs-lisp-checkdoc' and reduce the
  ;; `emacs-lisp' checker's verbosity.
  (add-hook 'flycheck-mode-hook #'+emacs-lisp-reduce-flycheck-errors-in-emacs-config-h)

  ;; Special fontification for elisp
  (font-lock-add-keywords
   'emacs-lisp-mode
   (append `(;; custom Doom cookies
             ("^;;;###\\(autodef\\|if\\|package\\)[ \n]" (1 font-lock-warning-face t)))
           ;; highlight defined, special variables & functions
           (when +emacs-lisp-enable-extra-fontification
             `((+emacs-lisp-highlight-vars-and-faces . +emacs-lisp--face)))))

  ;; Recenter window after following definition
  (advice-add #'elisp-def :after #'doom-recenter-a)

  (map! :localleader
        :map emacs-lisp-mode-map
        "e" #'macrostep-expand))


;;
;;; Packages

(map! :when (featurep! :editor evil)
      :after macrostep
      :map macrostep-keymap
      :n [return] #'macrostep-expand)


;;;###package overseer
(autoload 'overseer-test "overseer" nil t)
(remove-hook 'emacs-lisp-mode-hook 'overseer-enable-mode)


(def-package! flycheck-cask
  :when (featurep! :tools flycheck)
  :defer t
  :init
  (add-hook! 'emacs-lisp-mode-hook
    (add-hook 'flycheck-mode-hook #'flycheck-cask-setup nil t)))


(def-package! elisp-demos
  :defer t
  :init
  (advice-add 'describe-function-1 :after #'elisp-demos-advice-describe-function-1)
  (advice-add 'helpful-update :after #'elisp-demos-advice-helpful-update)
  :config
  (def-advice! +emacs-lisp-elisp-demos--search-a (orig-fn symbol)
    "Add Doom's own demos to help buffers."
    :around #'elisp-demos--search
    (or (funcall orig-fn symbol)
        (when-let* ((elisp-demos--elisp-demos.org (doom-glob doom-docs-dir "api.org")))
          (funcall orig-fn symbol)))))


(def-package! buttercup
  :defer t
  :minor ("/test[/-].+\\.el$" . buttercup-minor-mode)
  :config (set-yas-minor-mode! 'buttercup-minor-mode))


;;
;;; Project modes

(def-project-mode! +emacs-lisp-ert-mode
  :modes '(emacs-lisp-mode)
  :match "/test[/-].+\\.el$"
  :add-hooks '(overseer-enable-mode))
