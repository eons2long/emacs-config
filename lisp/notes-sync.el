;;; lisp/notes-sync.el -*- lexical-binding: t; -*-
;;; rclone luancher from emacs

(require 'cl-lib)
(require 'subr-x)

(defgroup my/note nil
  "note sync from Emacs."
  :group 'tools)

(defun my/note-on-termux-android-p ()
  "Return non-nil when running under Termux/Android."
  (or (string-match-p "android" system-configuration)
      (getenv "TERMUX_VERSION")
      (file-directory-p "/data/data/com.termux/files")))

(defcustom my/note-local
  (cond
  ((eq system-type 'darwin) (expand-file-name "~/Nutstore Files/Obsidian"))
  ((my/note-on-termux-android-p)
   (expand-file-name "/storage/emulated/0/ob/Obsidian"))
  (t
    (expand-file-name "~/notes")))
  "Local note directory"
  :type 'directory)

(defcustom my/note-remote "infini-ob:Obsidian"
  "rclone remote"
  :type 'string)

(defcustom my/note-sync-script (expand-file-name "~/dotfiles/sync.sh")
  "Script used to sync notes."
  :type 'file)

(defcustom my/note-sync-log-file
  (expand-file-name "notes-sync.log"
                    (if (boundp 'doom-user-dir)
                        doom-user-dir
                      user-emacs-directory))
  "File where the latest note sync output is written."
  :type 'file)

(defcustom my/note-sync-retries 3
  "Number of times to try a note sync command."
  :type 'integer)

(defcustom my/note-sync-retry-delay 5
  "Seconds to wait between note sync retries."
  :type 'integer)

(defcustom my/note-sync-ca-cert
  (cond
   ((file-readable-p "/opt/homebrew/etc/ca-certificates/cert.pem")
    "/opt/homebrew/etc/ca-certificates/cert.pem")
   ((file-readable-p "/usr/local/etc/ca-certificates/cert.pem")
    "/usr/local/etc/ca-certificates/cert.pem")
   (t nil))
  "CA bundle passed to rclone via RCLONE_CA_CERT, or nil to use rclone defaults."
  :type '(choice (const :tag "Use rclone defaults" nil)
                 file))

(defcustom my/note-sync-path
  (mapconcat #'identity
             (cl-remove-duplicates
              (cl-remove-if-not
               #'file-directory-p
               (delq nil
                     (append '("/opt/homebrew/bin" "/usr/local/bin")
                             exec-path
                             (parse-colon-path (or (getenv "PATH") ""))
                             '("/usr/bin" "/bin" "/usr/sbin" "/sbin"))))
              :test #'string=)
             path-separator)
  "PATH used when running note sync from GUI Emacs."
  :type 'string)

(defun my/note-sync--normalize-dir (dir)
  "Return a canonical PATH directory for DIR, or nil if it does not exist."
  (when (and dir (file-directory-p dir))
    (directory-file-name (expand-file-name dir))))

(defun my/note-sync-effective-path ()
  "Return a clean PATH for note sync child processes."
  (mapconcat
   #'identity
   (cl-remove-duplicates
    (delq nil
          (mapcar
           #'my/note-sync--normalize-dir
           (append '("/opt/homebrew/bin" "/usr/local/bin")
                   (parse-colon-path (or my/note-sync-path ""))
                   exec-path
                   (parse-colon-path (or (getenv "PATH") ""))
                   '("/usr/bin" "/bin" "/usr/sbin" "/sbin"))))
    :test #'string=)
   path-separator))

(defvar my/sync-note-buffer-name "*rclone-sync*")
(defvar my/sync-note-process nil)
(defvar my/sync-note-mode nil)
(defvar-local my/sync-note-cancelled nil)

(defun my/sync-note-current-process ()
  "Return the active note sync process, if any."
  (let ((proc (or my/sync-note-process
                  (get-buffer-process my/sync-note-buffer-name))))
    (when (and (processp proc) (process-live-p proc))
      proc)))

(defun my/sync-note--last-output-line ()
  "Return the last useful line in the sync buffer."
  (save-excursion
    (goto-char (point-max))
    (let (line)
      (while (and (not line) (not (bobp)))
        (forward-line -1)
        (let ((text (string-trim
                     (buffer-substring-no-properties
                      (line-beginning-position)
                      (line-end-position)))))
          (unless (or (string-empty-p text)
                      (string-prefix-p "Compilation " text))
            (setq line text))))
      line)))

(defun my/sync-note--last-diagnostic-line ()
  "Return the most useful recent diagnostic line in the sync buffer."
  (or (save-excursion
        (goto-char (point-max))
        (when (re-search-backward "\\(CRITICAL\\|ERROR\\|Failed\\):? .+" nil t)
          (string-trim (match-string-no-properties 0))))
      (my/sync-note--last-output-line)))

(defun my/sync-note-via-script (mode)
  "Run ~/dotfiles/sync.sh with env from Emacs"
  (when (my/sync-note-current-process)
    (user-error "A note sync is already running; use SPC r c to cancel it"))
  (unless (file-executable-p my/note-sync-script)
    (user-error "Sync script is not executable: %s" my/note-sync-script))
  (let* ((sync-log (expand-file-name my/note-sync-log-file))
         (retries (max 1 my/note-sync-retries))
         (ca-env (if (and my/note-sync-ca-cert
                          (file-readable-p my/note-sync-ca-cert))
                     (format " RCLONE_CA_CERT=%s"
                             (shell-quote-argument
                              (expand-file-name my/note-sync-ca-cert)))
                   ""))
         (inner-cmd
          (format (concat "set -o pipefail; "
                          "{ status=1; attempt=1; "
                          "while [ \"$attempt\" -le %d ]; do "
                          "if [ \"$attempt\" -gt 1 ]; then "
                          "echo \"retrying sync ($attempt/%d) after %ss...\"; "
                          "sleep %s; "
                          "fi; "
                          "env PATH=%s%s MODE=%s LOCAL_NOTE_PATH=%s REMOTE=%s %s; "
                          "status=$?; "
                          "[ \"$status\" -eq 0 ] && exit 0; "
                          "echo \"sync attempt $attempt/%d failed with exit $status\"; "
                          "attempt=$((attempt + 1)); "
                          "done; "
                          "exit \"$status\"; "
                          "} 2>&1 | /usr/bin/tee %s")
                  retries
                  retries
                  my/note-sync-retry-delay
                  (shell-quote-argument (number-to-string my/note-sync-retry-delay))
                  (shell-quote-argument (my/note-sync-effective-path))
                  ca-env
                  (shell-quote-argument mode)
                  (shell-quote-argument my/note-local)
                  (shell-quote-argument my/note-remote)
                  (shell-quote-argument my/note-sync-script)
                  retries
                  (shell-quote-argument sync-log)))
         (cmd (format "/bin/bash -lc %s" (shell-quote-argument inner-cmd)))
        (bufname my/sync-note-buffer-name)
        (display-buffer-alist
         '(("\\*rclone-sync\\*" display-buffer-no-window)))
        buf)
      (message "syncing (%s)..." mode)
      (setq buf
      (compilation-start cmd 'compilation-mode (lambda (_) bufname)))
      (with-current-buffer buf
        (setq my/sync-note-process (get-buffer-process buf)
              my/sync-note-mode mode)
        (setq-local mode-name "sync") ;; cosmetic if you even openit
        (setq-local my/sync-note-cancelled nil)
        ;;Replace the default finish message
        (setq-local compilation-exit-message-function
                    (lambda (status code _msg)
                      (let* ((ok (and (eq status 'exit) (zerop code)))
                             (last-line (unless ok
                                          (my/sync-note--last-diagnostic-line)))
                             (m (cond
                                 (my/sync-note-cancelled "sync cancelled")
                                 (ok "finished")
                                 (last-line
                                  (format "syncing failed (%s): %s" code last-line))
                                 (t (format "syncing failed (%s), see %s"
                                            code sync-log)))))
                        (setq my/sync-note-process nil
                              my/sync-note-mode nil)
                        (unless (or ok my/sync-note-cancelled)
                          (display-buffer (current-buffer)))
                        (message "%s" m)
                        ;; also return (message . face) for the buffer header
                        (cons m (if ok 'compilation-info 'compilation-error))))))))
;;;###autoload
(defun my/sync-note-push ()
  "Sync push local to remote."
  (interactive)
  (my/sync-note-via-script "push" ))

;;;###autoload
(defun my/sync-note-pull ()
  "Sync pull remote to local."
  (interactive)
  (my/sync-note-via-script "pull" ))

;;;###autoload
(defun my/sync-note-cancel ()
  "Cancel the current note sync process."
  (interactive)
  (let ((proc (my/sync-note-current-process)))
    (unless proc
      (user-error "No note sync process is running"))
    (with-current-buffer (process-buffer proc)
      (setq-local my/sync-note-cancelled t))
    (interrupt-process proc)
    (run-at-time
     1 nil
     (lambda (p)
       (when (and (processp p) (process-live-p p))
         (kill-process p)))
     proc)
    (message "sync cancel requested%s"
             (if my/sync-note-mode
                 (format " (%s)" my/sync-note-mode)
               ""))))
(provide 'notes-sync)
