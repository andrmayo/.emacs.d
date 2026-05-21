;;; -*- lexical-binding: t -*-

(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(load custom-file t)


;;; ============================================================================
;;; EMACS CORE PERFORMANCE SETTINGS
;;; ============================================================================

;; Increase the amount of data Emacs reads from processes
(setq read-process-output-max (* 1024 1024 4)) ; 4MB (default is 4KB)

;; (setq inhibit-startup-screen t)
(setq package-check-signature nil)
(setq backup-directory-alist `(("." . "~/.emacs_backups")))
(setq backup-by-copying t)
(setq delete-old-versions t
  kept-new-versions 6
  kept-old-versions 2
  version-control t)
(setq vc-make-backup-files t)

;;; ============================================================================
;;; PACKAGE MANAGEMENT
;;; ============================================================================

(require 'package)
(setq package-archives '())
 (add-to-list 'package-archives
              '("melpa" . "https://melpa.org/packages/"))
 (add-to-list 'package-archives
              '("gnu" . "https://elpa.gnu.org/packages/"))

(package-initialize)
;; (package-refresh-contents)

(unless (package-installed-p 'use-package)
  (package-install 'use-package))
(require 'use-package)
(setq use-package-always-ensure t)

;;; ============================================================================
;;; SYSTEM CONFIG
;;; ============================================================================

(use-package evil
  :config
  (evil-mode 1))

(setq ring-bell-function 'ignore)
(setq column-number-mode t)


(use-package exec-path-from-shell)
(when (memq window-system '(mac ns x pgtk))
  (exec-path-from-shell-initialize))

;; suppress launch page when emacs opens a file directly
(setq inhibit-startup-screen
      (cl-some #'file-exists-p command-line-args))


;; vim-style local and global leaders
(use-package general
    :config
    (general-create-definer leader-def
      :states '(normal emacs)
      :keymaps 'override
      :prefix "SPC")

    (general-create-definer local-leader-def
      :states '(normal emacs)
      :keymaps 'override
      :prefix "\\")

    (local-leader-def
      :keymaps 'startup-mode-map
      "s" 'restore-desktop))


;;; ============================================================================
;;; STARTUP
;;; ============================================================================

(require 'desktop)
(setq desktop-auto-save-timeout 120)

;; option to restore last emacs desktop
(let ((desktop-dir (expand-file-name "../.emacs-desktop/" user-emacs-directory)))
  (unless (file-directory-p desktop-dir)
    (make-directory desktop-dir t))
  (setq desktop-path (list desktop-dir)))

(add-hook 'kill-emacs-hook
          (lambda ()
            (cl-letf (((symbol-function 'yes-or-no-p) (lambda (&rest _) t)))
              (desktop-save (car desktop-path)))))

;; have <s> restore windows from emacs launch page
(defun restore-desktop ()
  (interactive)
  (desktop-read))

(defvar startup-mode-map (make-sparse-keymap))

;; minor mode for startup page
(define-minor-mode startup-mode
  "Enable shortcuts only on Emacs startup screen."
  :init-value nil
  :lighter " Start"
  :keymap startup-mode-map)


(defun enable-startup-mode ()
  (let ((buf (window-buffer (selected-window))))
    (when (string= (buffer-name buf) "*GNU Emacs*")
      (with-current-buffer buf
	(startup-mode 1)
	(evil-normal-state)))))

(add-hook 'window-setup-hook
	  (lambda ()
	    (run-with-timer 0.1 nil #'enable-startup-mode)))


;;; ============================================================================
;;; GENERAL CONFIG
;;; ============================================================================

(use-package smartparens-config
	     :ensure smartparens
	     :config
	     (progn
	       (show-smartparens-global-mode t)))
(smartparens-global-mode 1)

(use-package ivy
  :ensure t
  :config
;  :diminish ivy-mode
  (ivy-mode 1)
  (setq ivy-use-virtual-buffers t)
  (setq ivy-count-format "(%d/%d) ")
  (setq ivy-use-selectable-prompt t))

(use-package counsel
  :ensure t
  :config
;  :diminish counsel-mode
  (counsel-mode 1))

;; package for jumping between windows using displayed key mappings
(use-package ace-window
  :ensure t
  :init
  (setq aw-dispatch-always t)
  :defer t)

;;; ============================================================================
;;; DISPLAY
;;; ============================================================================

(global-display-line-numbers-mode 1)

;; color themes
 ;; (use-package sublime-themes
 ;;  :init (progn (load-theme 'mccarthy t)))
;; (use-package sublime-themes
;;        :init (progn (load-theme 'spolsky t)))
;; (use-package solarized-theme
;;   :init (progn (load-theme 'solarized-light t)))
(use-package solarized-theme
  :init (progn (load-theme 'solarized-dark t)))

;; Control the modeline appearance:
(use-package nerd-icons)
(use-package doom-modeline
  :ensure t
  :init (doom-modeline-mode 1)
  :config
  (setq doom-modeline-height 25)
  (setq doom-modeline-bar-width 3)
  (setq doom-modeline-icon t)
  (setq doom-modeline-major-mode-icon t))
