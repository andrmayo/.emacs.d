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


(setq ring-bell-function 'ignore)
(setq column-number-mode t)


;; uses a non-interactive shell for faster startup
(use-package exec-path-from-shell
  :config
  (setq exec-path-from-shell-arguments nil)
  (when (memq window-system '(mac ns x pgtk))
    (exec-path-from-shell-initialize)))


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

;; similar to neogit in nvim
(use-package magit)

;; show git change indicators in left margin, similar to gitsigns in nvim
(use-package diff-hl)
(global-diff-hl-mode)


;; imitating defaults for vim-floaterm
(use-package vterm)

(defvar float-term-buffer nil)
(defvar float-term-frame nil)

(defun float-term-toggle ()
  (interactive)
  (if (and (frame-live-p float-term-frame)
	   (frame-visible-p float-term-frame))
      (make-frame-invisible float-term-frame)
    (let* ((parent (selected-frame))
	   (pw (frame-pixel-width parent))
	   (ph (frame-pixel-height parent))
	   (fw (/ pw 2))
	   (fh (/ ph 2))
	   (fl (/ pw 4))
	   (ft (/ ph 4)))
      (unless (frame-live-p float-term-frame)
	(setq float-term-frame
	      (make-frame `((parent-frame . ,parent)
			    (width . (text-pixels . ,fw))
			    (height . (text-pixels . ,fh))
			    (left . ,fl)
			    (top . ,ft)
			    (minibuffer . nil)
			    (undecorated . t)
			    (internal-border-width . 2)))))
      (with-selected-frame float-term-frame
	(unless (and float-term-buffer (buffer-live-p float-term-buffer))
	  (setq float-term-buffer (vterm)))
	(switch-to-buffer float-term-buffer))
      (make-frame-visible float-term-frame)
      (select-frame-set-input-focus float-term-frame))))

(global-set-key (kbd "<f12>") #'float-term-toggle)

(with-eval-after-load 'vterm
  (define-key vterm-mode-map (kbd "<f12>") #'float-term-toggle))

(use-package paredit)

;;; ============================================================================
;;; EVIL
;;; ============================================================================

(use-package evil
  :init
  (setq evil-want-keybinding nil)
  (setq evil-want-C-i-jump nil)
  :config
  (setq evil-want-visual-char-semi-exclusive t)
  (evil-mode 1))

;; Evil behaves oddly in term mode
(evil-set-initial-state 'term-mode 'emacs)
(evil-set-initial-state 'vterm-mode 'emacs)

;; like commentary.vim
(use-package evil-commentary)
(evil-commentary-mode)

(use-package evil-smartparens)

(use-package evil-collection)
(evil-collection-init 'magit)

;; Like nvim-suround
;; ys for adding, ds for deleting, and cs for changing
;; customized so that
  ;; ┌─────────────┬───────────────────────────┐
  ;; │     Key     │         Produces          │
  ;; ├─────────────┼───────────────────────────┤
  ;; │ ( or ) or b │ ( )                       │
  ;; ├─────────────┼───────────────────────────┤
  ;; │ [ or ]      │ [ ]                       │
  ;; ├─────────────┼───────────────────────────┤
  ;; │ { or } or B │ { }                       │
  ;; ├─────────────┼───────────────────────────┤
  ;; │ >           │ < >                       │
  ;; ├─────────────┼───────────────────────────┤
  ;; │ t or <      │ prompts for HTML tag      │
  ;; ├─────────────┼───────────────────────────┤
  ;; │ f           │ prompts for function name │
  ;; └─────────────┴───────────────────────────┘

(use-package evil-surround
     :ensure t
     :config
     (global-evil-surround-mode 1)
    (setq-default evil-surround-pairs-alist
        '((?( . ("(" . ")"))
        (?[ . ("[" . "]"))
        (?{ . ("{" . "}"))
        (?) . ("(" . ")"))
        (?] . ("[" . "]"))
        (?} . ("{" . "}"))
        (?b . ("(" . ")"))
        (?B . ("{" . "}"))
        (?> . ("<" . ">"))
        (?t . evil-surround-read-tag)
        (?< . evil-surround-read-tag)
        (?\C-f . evil-surround-prefix-function)
        (?f . evil-surround-function))))

;; replaces Emac's linear undo
(use-package undo-tree
  :config
  (global-undo-tree-mode)
  (evil-set-undo-system 'undo-tree))

;; replicate and extend % behaviour in Vim
(use-package evil-matchit)
(global-evil-matchit-mode 1)

;; character-based navigation, like Flash in Neovim
(use-package avy)
(evil-define-key 'normal 'global (kbd "s") 'avy-goto-char)


;; replicate Flash treesitter-based selection and bind to "S"
;; add "inner" to treesit-jump-queries-filter-list if nodes are cluttered,
;; "inner" gives the inside of blocks
(use-package treesit-jump
  :vc (:url "https://github.com/dmille56/treesit-jump" :rev :newest)
  :config
  (setq treesit-jump-queries-filter-list '("test" "param"))
  (evil-define-key 'normal 'global (kbd "S") 'treesit-jump-jump)
  ;; copy over custom query directories
  (let ((custom-queries-dir (expand-file-name "treesit-queries/" user-emacs-directory)))
    (dolist (lang-dir (directory-files custom-queries-dir t "^[^.]"))
      (when (file-directory-p lang-dir)
	(let* ((lang (file-name-nondirectory lang-dir))
	       (src (expand-file-name "textobjects.scm" lang-dir))
	       (dst (expand-file-name (concat lang "/textobjects.scm") treesit-jump-queries-dir)))
	  (when (file-newer-than-file-p src dst)
	    (make-directory (file-name-directory dst) t)
	    (copy-file src dst t))))))
  ;; add emacs-lisp-mode to treesit-jump's record of major modes for languages
  (add-to-list 'treesit-jump-major-mode-language-alist '(emacs-lisp-mode . "elisp")))

(add-to-list 'treesit-language-source-alist
               '(python "https://github.com/tree-sitter/tree-sitter-python"))

(add-hook 'emacs-lisp-mode-hook (lambda () (treesit-parser-create 'elisp)))
(add-hook 'python-mode-hook (lambda () (treesit-parser-create 'python)))

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
