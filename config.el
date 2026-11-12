;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!
;; Android specific settings.
(defconst +on-termux-android
  (or (string-match-p "android" system-configuration)
          (getenv "TERMUX_VERSION")
          (file-directory-p "/data/data/com.termux/files")))

;; Hide owner/group columns on the narrow Termux display.
(when +on-termux-android
  (after! dired
    (ignore-errors
      (advice-remove #'dired-find-file #'dirvish-find-entry-a))
    (setq dired-hide-details-initially t)
    (add-hook! 'dired-mode-hook :append #'dired-hide-details-mode)
    (add-hook! 'dired-after-readin-hook :append #'dired-hide-details-mode)
    (setq dired-listing-switches "-Alh --group-directories-first -g -o")))

;; add lisp dir
(load! "lisp/notes-sync")
(defvar my-stopwatch--started-at nil
  "Start time of the active stopwatch, or nil when it is stopped.")

(defun my-stopwatch ()
  "Start the stopwatch, or insert elapsed time at point and reset it."
  (interactive)
  (if my-stopwatch--started-at
      (let* ((elapsed (max 0
                           (truncate
                            (float-time
                             (time-subtract (current-time)
                                            my-stopwatch--started-at)))))
             (hours (/ elapsed 3600))
             (minutes (if (zerop hours)
                          (/ elapsed 60)
                        (% (/ elapsed 60) 60)))
             (seconds (% elapsed 60))
             (result (if (zerop hours)
                         (format "- %02d:%02d" minutes seconds)
                       (format "- %02d:%02d:%02d" hours minutes seconds))))
        (insert result)
        (setq my-stopwatch--started-at nil)
        (when (and (fboundp 'evil-normal-state-p)
                   (evil-normal-state-p))
          (evil-insert-state)))
    (setq my-stopwatch--started-at (current-time))
    (message "Stopwatch started.")))

(map! :g "<f8>" #'my-stopwatch)

(map! :leader
      (:prefix ("r" . "Run/Sync")
       :desc "Sync notes push" "s" #'my/sync-note-push
       :desc "Sync notes pull" "p" #'my/sync-note-pull
       :desc "Cancel note sync" "c" #'my/sync-note-cancel))
;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
;; (setq user-full-name "John Doe"
;;       user-mail-address "john@doe.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
;;(setq doom-theme 'doom-one)
(setq doom-theme 'doom-dracula)
;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)
;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
;; change `org-directory'. It must be set before org loads!
(defconst yx-home
  (or (getenv "HOME") (getenv "USERPROFILE"))
  "Portable home directory")

(defun yx-path (&rest parts)
 (apply (if (fboundp 'file-name-concat) #'file-name-concat
        (lambda (a b)(expand-file-name b a)))
        parts))

(defconst yx-org-base
  (cond
   ((eq system-type 'darwin) (yx-path yx-home "Nutstore Files/Obsidian/org"))
   (+on-termux-android
;;    "/storage/emulated/0/Documents/obsidian/Obsidian/org")
      "/storage/emulated/0/ob/Obsidian/org")
   ((eq system-type 'gnu/linux) (yx-path yx-home "org"))
   (t (yx-path yx-home "org")))
  "Root of all org file across platforms.")

(defconst yx-org-inbox (expand-file-name "inbox.org" yx-org-base))
(setq org-directory yx-org-base)
  ;;  "Prompt for a project and set capture target to its Daily Progress Log heading."
(defun yx/org-capture-progress-file ()
  "Prompt for a project and set capture target to its Daily Progress Log heading."
  (let* ((project-list '("guanyin25"
                         "coca-2w-words"
                         "kiss-grd-100h"
                         ))
         (project (completing-read "Choose Project: " project-list nil t))
         (file (expand-file-name (format "projects/%s.org" project)
                                 org-directory)))
    (unless (file-exists-p file)
      (make-directory (file-name-directory file) t)
      (with-temp-buffer
        (insert "* Daily Progress Log\n")
        (write-file file)))
      file))
    ;; Ensure file exists and, if empty, initialize it with the heading
(after! org
  ;;  (setq org-directory "/Users/longgongmeishi/Nutstore Files/Obsidian/org/")
  (setq! org-agenda-files (directory-files-recursively org-directory "\\.org\\'"))
  (setq! org-capture-templates
        `(("t" "Todo" entry
           (file+headline ,yx-org-inbox "Inbox")
           "* TODO %?")
        ("p" "Progress" entry
         (file+headline yx/org-capture-progress-file "Progress Log")
         "* %<%Y-%m-%d %a> - %? \n:PROPERTIES:\n:Date: %<%Y-%m-%d>\n:Count: \n:END:"
         :empty-lines 1)
                    ))
  (setq! org-refile-targets '((org-agenda-files . (:maxlevel . 3))))
  (setq! org-refile-use-outline-path t)
  (setq! org-outline-path-complete-in-steps nil)
  ;; add done-log for org
  (setq org-log-done 'time)
  ;; setting GTD workflow
  (setq org-todo-keywords
        '((sequence "TODO(t)" "NEXT(n)" "|" "DONE(d)")
          (sequence "WAITING(w)" "BLOCKED(b)" "|" "CANCELLED(c)")))
  )

;; Configure Org-Roam and Org-Roam Dailies
;; -------------------------------------------------------------------------
(after! org-roam
  ;; -----------------------------------------------------------------------
  ;; 1. basic path setting
  ;; -----------------------------------------------------------------------
  (setq org-roam-directory (expand-file-name "roam" yx-org-base)
        org-roam-db-location (expand-file-name "org-roam.db" org-roam-directory))
  ;; -----------------------------------------------------------------------
  ;; 2. Normal Note  Capture template
  ;; -----------------------------------------------------------------------
 (setq org-roam-capture-templates
        `(("d" "default" plain "%?"
           :if-new (file+head "${slug}.org" "#+title: ${title}\n")
           :unnarrowed t)))
 ;; -----------------------------------------------------------------------
 ;; 3. Dailies Setting
 ;; -----------------------------------------------------------------------
  (setq org-roam-dailies-directory "daily/"
        org-roam-dailies-capture-templates
        `(("d" "daily" plain
           (file ,(expand-file-name "daily/template_2025.org" yx-org-base))
           :if-new (file+head "%<%Y-%m-%d>.org" "#+title: %<%Y-%m-%d>\n")
           ;;:unnarrowed t
           :immediate-finish nil
           )))
  (defun yx/org-daily-directory-for-time (time)
    "Return the personal daily directory for TIME."
    (let ((year-dir (expand-file-name (format-time-string "%Y年日志" time) yx-org-base)))
      (if (file-directory-p year-dir)
          year-dir
        (expand-file-name "daily" yx-org-base))))

  (defun yx/org-daily-file-for-time (time)
    "Return the personal daily file path for TIME."
    (expand-file-name (format-time-string "%Y-%m-%d.org" time)
                      (yx/org-daily-directory-for-time time)))

  (defun yx/org-open-daily-for-time (time)
    "Open the personal daily file for TIME."
    (let ((file (yx/org-daily-file-for-time time)))
      (make-directory (file-name-directory file) t)
      (unless (file-exists-p file)
        (with-temp-file file
          (insert (format "#+title: %s\n#+date: %s\n\n"
                          (format-time-string "%Y-%m-%d" time)
                          (format-time-string "%Y-%m-%d" time)))))
      (find-file file)
      (unless (derived-mode-p 'org-mode)
        (org-mode))))

  (defun yx/org-open-daily-date (time)
    "Open a personal daily file selected by date."
    (interactive (list (org-read-date nil t nil "Daily date: ")))
    (yx/org-open-daily-for-time time))

  (defun yx/org-open-daily-today ()
    "Open today's personal daily file."
    (interactive)
    (yx/org-open-daily-for-time (current-time)))

  (defun yx/org-open-daily-tomorrow ()
    "Open tomorrow's personal daily file."
    (interactive)
    (yx/org-open-daily-for-time (time-add (current-time) (days-to-time 1))))

  (defun yx/org-open-daily-yesterday ()
    "Open yesterday's personal daily file."
    (interactive)
    (yx/org-open-daily-for-time (time-subtract (current-time) (days-to-time 1))))
  ;; -----------------------------------------------------------------------
  (map! :leader
        (:prefix ("t" . "Notes")
         :desc "Find daily"      "d" #'yx/org-open-daily-date
         :desc "Find tomorrow"   "t" #'yx/org-open-daily-tomorrow
         :desc "Find yesterday"  "y" #'yx/org-open-daily-yesterday
         :desc "Find today"      "n" #'yx/org-open-daily-today
         :desc "Capture today"   "N" #'yx/org-open-daily-today
         :desc "Find node"       "f" #'org-roam-node-find
         :desc "Insert node"     "i" #'org-roam-node-insert)))

;; for the org-babel python3 setting
(setq org-babel-python-command "python3")
(setq python-shell-interpreter "python3")

;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `after!' block, otherwise Doom's defaults may override your settings. E.g.
;;
;;   (after! PACKAGE
;;     (setq x y))
;(setq doom-theme 'doom-challenger-deep)
;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look up their documentation).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.
;;
;;set markdown color
;(when (not (display-graphic-p))
;  (custom-set-faces!
;   '(default :foreground "#ffd8af")))
 (custom-set-faces!
  '(region :background "#44475a" :foreground "#ffffff")
  ;; '(region :background "#6272a4" :foreground "#ffffff")
)

;; Preview Markdown images in terminal Emacs via iTerm2's imgcat protocol.
(after! markdown-mode
  (require 'subr-x)

  (defvar yx/imgcat-width "80%")

  (defun yx/imgcat-executable ()
    (or (executable-find "imgcat")
        (let ((imgcat (expand-file-name "~/.local/bin/imgcat")))
          (when (file-executable-p imgcat)
            imgcat))))

  (defun yx/markdown-image-target-at-point ()
    (or
     (save-excursion
       (let ((pos (point))
             target)
         (goto-char (line-beginning-position))
         (while (and (not target)
                     (re-search-forward "!\\[[^]\n]*\\](\\s-*\\([^)\n\t ]+\\)" (line-end-position) t))
           (when (or (and (<= (match-beginning 0) pos)
                          (<= pos (match-end 0)))
                     (not target))
             (setq target (match-string-no-properties 1))))
         (when target
           (string-trim target "<" ">"))))
     (thing-at-point 'url t)))

  (defun yx/markdown-preview-image-at-point ()
    (interactive)
    (let* ((target (yx/markdown-image-target-at-point))
           (imgcat (yx/imgcat-executable)))
      (unless target
        (user-error "No Markdown image URL found on this line"))
      (unless imgcat
        (user-error "imgcat executable not found"))
      (let ((args (append (list "-n" "-r" "-W" yx/imgcat-width)
                          (if (string-match-p "\\`https?://" target)
                              (list "-u" target)
                            (list "-f" (expand-file-name target))))))
        (with-temp-buffer
          (let ((status (apply #'call-process imgcat nil (list t t) nil args)))
            (unless (eq status 0)
              (user-error "imgcat failed: %s" (string-trim (buffer-string))))
            (send-string-to-terminal (buffer-string))
            (message "Sent image preview to iTerm"))))))

  (map! :map markdown-mode-map
        :localleader
        :desc "Preview image with imgcat" "p i" #'yx/markdown-preview-image-at-point))

;;set the clipboard for macos
;;; --- macOS Specific Settings ---
(when (and (string-equal system-type "darwin") (not (display-graphic-p)))
  (defun copy-to-osx-clipboard (text &optional push)
    "Write TEXT to the macOS clipboard."
    (with-temp-buffer
      (insert text)
      (call-process-region (point-min) (point-max) "pbcopy" nil 0 nil)))

  (defun paste-from-osx-clipboard ()
    "Read and return content from the macOS clipboard."
    (with-temp-buffer
      (when (and (zerop (call-process "pbpaste" nil t nil))
                 (> (buffer-size) 0))
        (buffer-string))))

  (setq interprogram-cut-function #'copy-to-osx-clipboard)
  (setq interprogram-paste-function #'paste-from-osx-clipboard))
;;; ================================================================
(setq evil-default-command-delay 0.05)
;;
;;
(when (string-equal system-type "darwin")

(use-package! exec-path-from-shell
  :if (eq system-type 'darwin)
  :config
  (dolist (var '("PATH" "HW_API_KEY" "OPENROUTER_API_KEY" "DEEPSEEK_API_KEY"))
    (add-to-list 'exec-path-from-shell-variables var))
  (exec-path-from-shell-initialize)
  ;; Keep Cargo, rustc, and rust-analyzer on the same rustup toolchain.
  (let ((cargo-bin (expand-file-name "~/.cargo/bin")))
    (setq exec-path (cons cargo-bin (remove cargo-bin exec-path)))
    (setenv "PATH"
            (mapconcat #'identity
                       (cons cargo-bin
                             (remove cargo-bin
                                     (split-string (getenv "PATH") path-separator)))
                       path-separator))))

(after! geiser
  (setq geiser-active-implementations '(racket)
      geiser-default-implementation 'racket
      geiser-racket-binary "/Applications/Racket v8.18/bin/racket"
      geiser-repl-per-project-p t)
)
;; for minuet
(use-package! minuet
  :defer t
  :init
  (add-hook 'prog-mode-hook #'minuet-auto-suggestion-mode)
  :config
  (setq minuet-provider 'openai-fim-compatible
        minuet-request-timeout 10
        minuet-show-error-message-on-minibuffer t
        minuet-auto-suggestion-throttle-delay 1.8
        minuet-auto-suggestion-debounce-delay 0.7
        minuet-n-completions 1
        minuet-context-window 768)

  (plist-put minuet-openai-fim-compatible-options :name "DeepSeek-V4.1-Flash")
  (plist-put minuet-openai-fim-compatible-options
             :end-point "https://api.deepseek.com/beta/completions")
  (plist-put minuet-openai-fim-compatible-options :api-key "DEEPSEEK_API_KEY")
  (plist-put minuet-openai-fim-compatible-options :model "deepseek-flash")
  (minuet-set-optional-options minuet-openai-fim-compatible-options :max_tokens 96)
  (minuet-set-optional-options minuet-openai-fim-compatible-options :top_p 0.9)

  (defun yx-minuet-accept-suggestion-word ()
    "Accept one identifier or punctuation character from Minuet."
    (interactive)
    (when-let* ((_ minuet--current-overlay)
                (suggestion
                 (nth minuet--current-suggestion-index
                      minuet--current-suggestions)))
      (let* ((end
              (if (string-match
                   "\\`[[:space:]]*\\(?:[[:alnum:]_]+\\|[^[:space:]]\\)"
                   suggestion)
                  (match-end 0)
                (length suggestion)))
             (accepted (substring suggestion 0 end))
             (remaining (substring suggestion end)))
        ;; Minuet recognizes its commands by name to avoid fresh AI requests.
        (setq this-command 'minuet-accept-suggestion)
        (minuet--cleanup-suggestion)
        (insert accepted)
        (unless (string-empty-p remaining)
          (minuet--display-suggestion (list remaining) 0)))))

  (map! :map minuet-active-mode-map
        "M-p" #'minuet-previous-suggestion
        "M-n" #'minuet-next-suggestion
        "M-f" #'yx-minuet-accept-suggestion-word
        "M-L" #'minuet-accept-suggestion
        "M-l" #'minuet-accept-suggestion-line
        "M-e" #'minuet-dismiss-suggestion)

  (map! :i "M-i" #'minuet-show-suggestion
        :i "M-y" #'minuet-complete-with-minibuffer))

(defun yx-corfu-completion-active-p (&rest _)
  "Return non-nil while Corfu is completing in the current buffer."
  (and (bound-and-true-p corfu-mode)
       (bound-and-true-p completion-in-region-mode)))

(defun yx-minuet-dismiss-for-corfu (&rest _)
  "Clear Minuet suggestions and pending requests when Corfu opens."
  (minuet-dismiss-suggestion))

(after! minuet
  (add-hook 'minuet-auto-suggestion-block-predicates
            #'yx-corfu-completion-active-p)
  ;; A late streaming response must not recreate grey text over Corfu.
  (advice-add 'minuet--display-suggestion :before-until
              #'yx-corfu-completion-active-p)
  (after! corfu
    (advice-add 'corfu--popup-show :before
                #'yx-minuet-dismiss-for-corfu)))

;; for gptel
(use-package! gptel
  :init
  (load! "gptel-prompts.el")
  :config
  (setq gptel-model 'gpt-5.6-luna)
  (setq gptel-include-reasoning nil)

  (require 'gptel-openai-oauth)
  (gptel-make-openai-oauth "OpenAI-sub")

  (gptel-make-ollama "Ollama"
    :host "localhost:11434"
    :stream t
    :models '(
              (qwen3:8b    . "qwen3:8b")
              (qwen3.5:9b  . "qwen3.5:9b")
              (qwen-vl-8b . "qwen3-vl:8b")))

  (gptel-make-openai "openrouter"
    :host "openrouter.ai"
    :endpoint "/api/v1/chat/completions"
    :stream t
    :key (getenv "OPENROUTER_API_KEY")
    :models '(
            (deepseek-v4-flash    . "deepseek/deepseek-v4-flash")
            (gemini-3-pro-preview . "google/gemini-3-pro-preview")
            (minimax-m2.5 . "minimax/minimax-m2.5")
            (grok-4.1-fast . "x-ai/grok-4.1-fast")
            (grok-4.20 . "x-ai/grok-4.20")
            (grok-4.20-multi-agent . "x-ai/grok-4.20-multi-agent")
            (gemini-3-flash-preview . "google/gemini-3-flash-preview")))

  (setq gptel-backend (gptel-get-backend "OpenAI-sub")
        gptel-default-mode 'org-mode)

  (map! :map gptel-mode-map
        "C-c m" #'gptel-menu)
  )

(map! :leader
      :desc "GPTel send"
      "v s" #'gptel-send)

(require 'seq)

(defvar my-herdr-target-pane 'rightmost
  "Target pane strategy for Herdr commands.
Can be:
- 'rightmost: dynamically detect the rightmost pane of the current tab.
- A string (e.g. \"wW:p7\"): send to a specific fixed pane ID.")

(defvaralias 'my-herdr-codex-target 'my-herdr-target-pane)

(defun my/herdr-get-rightmost-pane ()
  "Get the pane ID of the rightmost pane in the current Herdr tab."
  (unless (executable-find "herdr")
    (user-error "Cannot find herdr in exec-path"))
  (with-temp-buffer
    (let ((status (call-process "herdr" nil t nil "pane" "layout")))
      (unless (and (integerp status) (zerop status))
        (user-error "Failed to get Herdr layout (%s): %s" status (buffer-string)))
      (goto-char (point-min))
      (let* ((data (json-parse-buffer :object-type 'alist :array-type 'list))
             (layout (alist-get 'layout (alist-get 'result data)))
             (panes (alist-get 'panes layout)))
        (unless panes
          (user-error "No panes found in current Herdr tab"))
        ;; If currently zoomed, return the focused zoomed pane
        (if (eq (alist-get 'zoomed layout) t)
            (alist-get 'focused_pane_id layout)
          (let ((rightmost
                 (seq-reduce
                  (lambda (best p)
                    (let* ((r (alist-get 'rect p))
                           (br (alist-get 'rect best))
                           (rx (+ (or (alist-get 'x r) 0) (or (alist-get 'width r) 0)))
                           (brx (+ (or (alist-get 'x br) 0) (or (alist-get 'width br) 0))))
                      (cond
                       ((> rx brx) p)
                       ((< rx brx) best)
                       ;; Prefer currently focused pane when tied
                       ((and (eq (alist-get 'focused p) t)
                             (not (eq (alist-get 'focused best) t)))
                        p)
                       (t best))))
                  (cdr panes)
                  (car panes))))
            (alist-get 'pane_id rightmost)))))))

(defun my/herdr-codex-prompt (prompt)
  "Send PROMPT and Enter to the target Herdr pane (default: rightmost pane in current tab)."
  (interactive (list (read-string "Prompt for Herdr: ")))
  (unless (executable-find "herdr")
    (user-error "Cannot find herdr in exec-path"))
  (let ((target (if (stringp my-herdr-target-pane)
                    my-herdr-target-pane
                  (my/herdr-get-rightmost-pane))))
    (with-temp-buffer
      (let ((status
             (call-process "herdr" nil t nil
                           "pane" "run" target prompt)))
        (unless (and (integerp status) (= status 0))
          (user-error "Herdr submission failed (%s): %s"
                      status (buffer-string)))))
    (message "Prompt sent to Herdr pane at %s" target)))

(map! :leader
      (:prefix ("v" . "ai")
       :desc "Minuet complete" "m" #'minuet-complete-with-minibuffer
       :desc "Minuet suggest" "i" #'minuet-show-suggestion
       :desc "Minuet configure" "M" #'minuet-configure-provider
       :desc "Herdr Codex prompt" "p" #'my/herdr-codex-prompt))

(load! "lisp/arkts-ts-mode")
(add-to-list 'auto-mode-alist '("\\.ets\\'" . arkts-ts-mode))
(add-to-list 'auto-mode-alist '("/ets/.+\\.ts\\'" . arkts-ts-mode))
(setq treesit-font-lock-level 4)

(after! eglot
  (setf (alist-get 'arkts-ts-mode eglot-server-programs nil nil #'equal)
        `("ets-language-server" "--stdio"
          :initializationOptions
          (:ets (:sdkPath ,(expand-file-name "~/Library/OpenHarmony/Sdk/20"))))))
(add-hook 'arkts-ts-mode-hook #'eglot-ensure)

(add-to-list 'auto-mode-alist '("\\.rkt\\'" . racket-mode))

(use-package! sdcv
  :config
  (require 'subr-x)
  ;; `sdcv-say-word-p' is not a variable in sdcv.el, so the old setting did nothing.
  ;; The real switch is `sdcv-word-pronounce' (default t), which blocks for a second
  ;; and then calls espeak -- absent on macOS.
  (setq sdcv-word-pronounce nil)

  ;; Without these lists sdcv searches every installed dictionary and prints each
  ;; hit, which buries one word under a screenful of compounds and proverbs.
  ;; 简明英汉词典 covers English lookups, 汉语辞海 covers Chinese ones.
  (setq sdcv-dictionary-complete-list '("简明英汉词典" "汉语辞海"))
  (setq sdcv-dictionary-simple-list   '("简明英汉词典" "汉语辞海"))

  ;; StarDict spells phonetics in its own ASCII alphabet: `apple' is "5Apl" and
  ;; `church' is "tFE:tF".  Map it back to IPA; `:' marks a long vowel, and a
  ;; few symbols change value in front of it.
  (defconst yx-sdcv-ipa-table
    '(("A" . "æ") ("B" . "ɑ") ("C" . "ɔ") ("E" . "ə") ("F" . "ʃ")
      ("I" . "ɪ") ("J" . "ʊ") ("L" . "ə") ("N" . "ŋ") ("Q" . "ʌ")
      ("R" . "ɔ") ("T" . "ð") ("U" . "u") ("V" . "ʒ") ("W" . "θ")
      ("Z" . "e") ("^" . "ɡ") ("\\" . "ɜ") ("5" . "ˈ") ("7" . "ˌ")
      ("9" . "ˌ") ("`" . "ˈ") ("i" . "ɪ") ("u" . "ʊ") (":" . "ː"))
    "StarDict ASCII phonetic symbols mapped to IPA.")

  (defconst yx-sdcv-ipa-long-table
    '(("E" . "ɜ") ("I" . "i") ("J" . "u") ("U" . "u") ("i" . "i") ("u" . "u"))
    "Symbols that take a different IPA value before a length mark.")

  (defun yx-sdcv-ipa (ph)
    "Translate the StarDict phonetic PH into IPA."
    (let ((ph (car (split-string ph "[;,]"))))       ; keep the first variant
      (setq ph (replace-regexp-in-string "([^)]*)\\|[-() ]" "" ph))
      (replace-regexp-in-string
       "\\(.\\)\\(:\\)?"
       (lambda (match)
         (let* ((sym (substring match 0 1))
                (long (= 2 (length match)))
                (ipa (or (and long (cdr (assoc sym yx-sdcv-ipa-long-table)))
                         (cdr (assoc sym yx-sdcv-ipa-table))
                         sym)))
           (concat ipa (if long "ː" ""))))
       ph t)))

  ;; The dictionaries store their entries as XML and sdcv prints it verbatim;
  ;; strip the markup so only the text remains.  sdcv's "Nothing similar to X"
  ;; notice is English here, so `sdcv-filter' never matches it and would leave
  ;; an empty buffer; fall back to an explicit message.
  (defun yx-sdcv--strip-markup (result)
    "Reduce sdcv RESULT to plain text, rendering phonetics in IPA."
    (with-temp-buffer
      (insert result)
      ;; Phonetics go first: only their markup tells us what they are.
      (goto-char (point-min))
      (while (re-search-forward "<词典音标><!\\[CDATA\\[\\([^]]*\\)\\]\\]></词典音标>" nil t)
        ;; `split-string' below clobbers the match data, so keep ours intact.
        (let ((ipa (save-match-data (yx-sdcv-ipa (match-string 1)))))
          (replace-match (if (string-blank-p ipa) "" (format "/%s/" ipa)) t t)))
      ;; Unwrap the remaining CDATA, then drop the tags around it.
      (goto-char (point-min))
      (while (re-search-forward "<!\\[CDATA\\[\\([^]]*\\)\\]\\]>" nil t)
        (replace-match (match-string 1) t t))
      (goto-char (point-min))
      (while (re-search-forward "</?[^<>\n]+>" nil t)
        (replace-match "" t t))
      ;; Collapse the runs of blank lines the tags leave behind.
      (goto-char (point-min))
      (while (re-search-forward "[ \t]*\n[ \t\n]*" nil t)
        (replace-match "\n" t t))
      (setq result (string-trim (buffer-string))))
    (if (string-blank-p result)
        (format "No entry for `%s'." sdcv-current-translate-object)
      result))
  (unless (advice-member-p #'yx-sdcv--strip-markup #'sdcv-filter)
    (advice-add #'sdcv-filter :filter-return #'yx-sdcv--strip-markup))

  ;; A lookup answers in a few lines now, so show it under the minibuffer
  ;; instead of splitting the window.  `sdcv-search-with-dictionary-args' also
  ;; records the word for the "No entry" message above.
  (defun yx-sdcv-entry (word)
    "Return sdcv's entry for WORD as plain text."
    (with-temp-buffer
      (apply #'call-process "sdcv" nil t nil
             (sdcv-search-with-dictionary-args
              word sdcv-dictionary-complete-list))
      (string-trim
       (replace-regexp-in-string "^-->.*\n" "" (sdcv-filter (buffer-string))))))

  (defun yx-sdcv-message (word)
    "Show the dictionary entry for WORD under the minibuffer."
    (interactive (list (read-string "Word: " nil nil (thing-at-point 'word t))))
    (message "%s" (yx-sdcv-entry word)))

  (defun yx-sdcv-message-at-point ()
    "Show the entry for the word at point under the minibuffer."
    (interactive)
    (yx-sdcv-message (or (thing-at-point 'word t)
                         (user-error "No word at point"))))

  (map! :leader
        (:prefix ("d" . "dictionary")
         :desc "Lookup in minibuffer" "s" #'yx-sdcv-message
         :desc "Lookup word at point" "S" #'yx-sdcv-message-at-point
         :desc "Lookup in buffer" "b" #'sdcv-search-input))
  ))

(when (eq system-type 'darwin)
  (defconst yx-emacs-rime-data-dir
    (expand-file-name "rime" "~/.local/share/emacs"))

  (defconst yx-liberime-core-module-file
    (expand-file-name "../liberime/lib/liberime-core.dylib"
                      yx-emacs-rime-data-dir))

  ;; Keep librime's writable user data separate from Squirrel's LevelDB files.
  ;; The shared directory below is Squirrel's read-only bundled Rime data only.
  ;; Rime sync also snapshots custom YAML, so keep sync manual and private.
  (setq liberime-user-data-dir yx-emacs-rime-data-dir
        liberime-shared-data-dir
        "/Library/Input Methods/Squirrel.app/Contents/SharedSupport"
        liberime-module-file yx-liberime-core-module-file
        liberime-load-on-require nil)

  (use-package! liberime
    :demand t
    :config
    (liberime-load)
    (liberime-try-select-schema "wubi86_jidian"))

  (use-package! rimel
    :after liberime
    :demand t
    :init
    (setq rimel-schema "wubi86_jidian"
          default-input-method "rimel")
    :config
    (add-to-list 'rimel-disable-predicates
                 #'rimel-predicate-prog-in-code-p)))
