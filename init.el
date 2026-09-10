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
      :states '(normal)
      :keymaps 'override
      :prefix "SPC")

    (general-create-definer local-leader-def
      :states '(normal visual emacs)
      :prefix "\\")

    (leader-def
      "E" 'session-dired-sidebar
      "fd" 'session-fzf
      "fc" (lambda () (interactive) (find-file user-init-file))
      "/" 'counsel-rg)
    
    (local-leader-def
      :keymaps 'startup-mode-map
      "s" 'restore-desktop))


;;; ============================================================================
;;; STARTUP AND SHUTDOWN
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


;; PWD of the shell that launched this frame (via emacsclient --eval, see
;; .bashrc's `emacs` function). Stored per-frame so it survives visiting
;; files elsewhere without clobbering their own default-directory, and so
;; multiple frames launched from different shells don't stomp on each other.
(defvar emacs--next-frame-pwd nil
  "PWD to attach to the next frame created via emacsclient, set externally.")

(require 'project)

(defun session-pwd (&optional frame)
  "Return the PWD of the shell that launched FRAME (or the selected frame).
Falls back to `default-directory' if the frame wasn't launched via the
`emacs' shell wrapper (e.g. GUI Emacs, or a frame that predates it)."
  (or (frame-parameter (or frame (selected-frame)) 'session-pwd)
      default-directory))

(defun session-shell ()
  "Open a shell in the PWD of the shell that launched this frame."
  (interactive)
  (let ((default-directory (session-pwd)))
    (shell (generate-new-buffer-name (format "*shell: %s*" default-directory)))))

(defun session-root ()
  "Return the current buffer's project root, falling back to `session-pwd'.
Lets project-aware commands stay scoped to the project you're editing,
while still defaulting to the launching shell's directory outside of one."
  (if-let* ((proj (project-current)))
      (project-root proj)
    (session-pwd)))

(defun session-fzf ()
  "Run `counsel-fzf' rooted at `session-root' rather than the buffer's directory."
  (interactive)
  (counsel-fzf nil (session-root)))

(defun session-dired-sidebar ()
  "Toggle `dired-sidebar' rooted at `session-root' rather than the buffer's directory."
  (interactive)
  (dired-sidebar-toggle-sidebar (session-root)))

(leader-def "'" 'session-shell)

;; ensure default buffer on start is *GNU Emacs* even when using emacsclient
(add-hook 'server-after-make-frame-hook
	  (lambda ()
      (when emacs--next-frame-pwd
        (set-frame-parameter (selected-frame) 'session-pwd emacs--next-frame-pwd)
        (setq default-directory emacs--next-frame-pwd)
        (setq emacs--next-frame-pwd nil))
      (when (string= (buffer-name) "*scratch*")
        (if (display-graphic-p)
            (fancy-startup-screen)
          (normal-splash-screen))
        (run-with-timer 0.1 nil #'enable-startup-mode))))

(add-hook 'window-setup-hook
	  (lambda ()
	    (run-with-timer 0.1 nil #'enable-startup-mode)))


;; open terminal on exiting emacs
;; requires something like 'ghostty --working-directory=%s' to be passed to emacsclient
;; with
;; emacsclient -c --eval "(setenv \"EMACS_TERMINAL_CMD\" \"ghostty --working-directory=%s\")" "$@" & disown

;; if using ghostty, add this to .bashrc:

; EMACS_TERMINAL_CMD="ghostty --working-directory=%s"
; EMACS_TERM_ENV_CMD="(setenv \"EMACS_TERMINAL_CMD\" \"$EMACS_TERMINAL_CMD\")"
;
; emacs() {
;   local dir_cmd="(setq emacs--next-frame-pwd \"$PWD/\")"
;   if emacsclient -e 't' 2>/dev/null; then
;     emacsclient --eval "$EMACS_TERM_ENV_CMD" >/dev/null 2>&1
;     emacsclient --eval "$dir_cmd" >/dev/null 2>&1 &
;     emacsclient -c "$@" &
;     disown
;     sleep 0.25
;   else
;     command emacs --daemon
;     emacsclient --eval "$EMACS_TERM_ENV_CMD" >/dev/null 2>&1
;     emacsclient --eval "$dir_cmd" >/dev/null 2>&1 &
;     emacsclient -c "$@" &
;     disown
;     sleep 0.5
;   fi
;   exit
; }
;
; emacs-t() {
;   emacsclient -t "$@" 2>/dev/null || { command emacs --daemon && emacsclient -t "$@"; }
; }
;
; emacs-stop() {
;   emacsclient -e '(setenv "EMACS_TERMINAL_CMD" nil)' >/dev/null 2>&1
;   emacsclient -e '(kill-emacs)' >/dev/null 2>&1
; }


(add-hook 'delete-frame-functions
	  (lambda (frame)
	    (when (and (<= (length (filtered-frame-list #'display-graphic-p)) 1)
		       (getenv "EMACS_TERMINAL_CMD"))
	      (let* ((term-cmd (getenv "EMACS_TERMINAL_CMD"))
               (dir (expand-file-name (session-pwd frame)))
               (cmd (format term-cmd dir))
               (parts (split-string cmd " ")))
		(apply #'start-process "terminal" nil "setsid" parts)))))


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

(use-package dired
  :ensure nil
  :hook (dired-mode . auto-revert-mode))

;; package for sidebar directory exploration
(use-package dired-sidebar
  :commands dired-sidebar-toggle-sidebar
  :config
  (advice-add 'dired-sidebar-toggle-sidebar :after
	      (lambda (&rest _)
		(when (dired-sidebar-showing-sidebar-p)
		  (dired-sidebar-refresh-buffer)))))

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
;;; Common Lisp (Sly)
;;; ============================================================================

(use-package sly
  :init
  (setq inferior-lisp-program "sbcl")
  (setq sly-lisp-implementations
        '((sbcl ("sbcl") :coding-system utf-8-unix)
          (qlot ("qlot" "exec" "ros" "run") :coding-system utf-8-unix)))
  :hook (lisp-mode . sly-editing-mode))

(local-leader-def
  :keymaps 'lisp-mode-map
  "r" (list :def (lambda () (interactive)
                   (let ((current-prefix-arg '-))
                     (call-interactively #'sly)))
            :which-key "start sly (choose implementation)")
  "q" (list :def (lambda ()
                   (interactive)
                   ;; call `sly-start' directly (rather than `(sly 'qlot)')
                   ;; so :directory always `cd's the inferior-lisp buffer,
                   ;; even if that buffer is being reused from a previous,
                   ;; differently-rooted invocation.
                   (sly-start :program "qlot"
                              :program-args '("exec" "ros" "run")
                              :coding-system 'utf-8-unix
                              :directory (session-root)
                              :name 'qlot))
            :which-key "start sly (qlot)"))

(use-package which-key
  :config
  (which-key-mode))

;;; ============================================================================
;;; EVIL
;;; ============================================================================

(use-package evil
  :init
  (setq evil-want-keybinding nil)
  (setq evil-want-C-i-jump nil)
  (setq evil-want-C-u-scroll t)
  :config
  (setq evil-want-visual-char-semi-exclusive t)
  (evil-mode 1))

;; Evil behaves oddly in term mode
(evil-set-initial-state 'term-mode 'emacs)
(evil-set-initial-state 'vterm-mode 'emacs)

;; flash a highlight on yank/delete/paste, etc.
;; (not using `evil-goggles-use-diff-faces': its `diff-changed' face has no
;; background under doom-solarized-dark, making yank nearly invisible;
;; doom-themes already ships a properly contrasted `evil-goggles-default-face')
(use-package evil-goggles
  :ensure t
  :config
  (evil-goggles-mode))

;; like commentary.vim
(use-package evil-commentary)
(evil-commentary-mode)

(use-package evil-smartparens
             :config
             (add-hook 'smartparens-enabled-hook #'evil-smartparens-mode))

(use-package evil-collection)
(evil-collection-init '(dired magit sly))

;; so that "a" can create files and directories
(defun dired-create-dir-or-file ()
  (interactive)
  (let ((name (read-string "Create (append / for directory): ")))
    (if (string-suffix-p "/" name)
	(dired-create-directory name)
      (dired-create-empty-file name))))

;; so that "d" toggled marking for deletion
(defun dired-toggle-flag-deletion ()
  (interactive)
  (if (eq (char-after (line-beginning-position)) dired-del-marker)
      (dired-unmark 1)
    (dired-flag-file-deletion 1)))

;; setup keybinding in dired sidebar
;; dired already has "d" for marking for deletion
(with-eval-after-load 'dired
      (evil-define-key 'normal dired-mode-map
	"l" 'dired-find-file
	"h" 'dired-up-directory
	"a" 'dired-create-dir-or-file
	"r" 'dired-do-rename
	"c" 'dired-do-copy
	"d" 'dired-toggle-flag-deletion
	"D" 'dired-do-flagged-delete
	"x" 'dired-do-delete))

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
        '((?\( . ("(" . ")"))
        (?\[ . ("[" . "]"))
        (?{ . ("{" . "}"))
        (?\) . ("(" . ")"))
        (?\] . ("[" . "]"))
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

;; vim style movement between buffers
;; include 'motion state, since many read-only/special-mode buffers
;; use motion state rather than normal state
(evil-define-key '(normal motion emacs) 'global (kbd "H") 'centaur-tabs-backward)
(evil-define-key '(normal motion emacs) 'global (kbd "L") 'centaur-tabs-forward)

;;; ============================================================================
;;; Treesitter
;;; ============================================================================

;; Add grammar sources
(with-eval-after-load 'treesit
  (add-to-list 'treesit-language-source-alist
               '(elisp "https://github.com/Wilfred/tree-sitter-elisp"))
  (add-to-list 'treesit-language-source-alist
	       '(commonlisp "https://github.com/tree-sitter-grammars/tree-sitter-commonlisp"))
  (add-to-list 'treesit-language-source-alist
		'(python "https://github.com/tree-sitter/tree-sitter-python")))

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
  (add-to-list 'treesit-jump-major-mode-language-alist '(emacs-lisp-mode . "elisp"))
  (add-to-list 'treesit-jump-major-mode-language-alist '(lisp-mode . "commonlisp")))


(add-hook 'emacs-lisp-mode-hook (lambda () (when (treesit-language-available-p 'elisp) (treesit-parser-create 'elisp))))
(add-hook 'python-mode-hook (lambda () (when (treesit-language-available-p 'python) (treesit-parser-create 'python))))
(add-hook 'lisp-mode-hook (lambda () (when (treesit-language-available-p 'commonlisp) (treesit-parser-create 'commonlisp))))

;;; ============================================================================
;;; LSP (Eglot)
;;; ============================================================================

;; built-in, minimal LSP client (like nvim-lspconfig: just talks LSP,
;; no bundled UI), rather than the heavier lsp-mode framework
(use-package eglot
  :ensure nil
  :hook (python-mode . eglot-ensure))

;; SPC s s: fuzzy-jump to a symbol in the current buffer via imenu,
;; which eglot populates from the LSP server's document symbols
;; (matches neovim's <leader>ss, LSP document symbols)
(leader-def "ss" 'counsel-imenu)

;; show counsel-imenu as a floating window (like `float-term-toggle')
;; instead of in the minibuffer; other ivy/counsel prompts are unaffected
(use-package ivy-posframe
  :ensure t
  :after ivy
  :config
  (setq ivy-posframe-display-functions-alist
        '((counsel-imenu . ivy-posframe-display-at-frame-center)
          (counsel-fzf . ivy-posframe-display-at-frame-center)))
  (ivy-posframe-mode 1))

;;; ============================================================================
;;; DISPLAY
;;; ============================================================================

(global-display-line-numbers-mode 1)

;; color themes
(use-package doom-themes
  :ensure t
  :init (progn (load-theme 'doom-one t)))

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

;; visual buffer tabs across the top, like a neovim bufferline
(use-package centaur-tabs
  :ensure t
  :init
  (setq centaur-tabs-set-icons t)
  (setq centaur-tabs-icon-type 'nerd-icons)
  (setq centaur-tabs-set-bar 'under)
  (setq centaur-tabs-set-modified-marker t)
  :config
  (centaur-tabs-mode t))

;; color matching parens/brackets by nesting depth
(use-package rainbow-delimiters
  :ensure t
  :hook (prog-mode . rainbow-delimiters-mode))

;; dim the background of non-file buffers (sidebar, REPLs, popups)
;; so the buffer you're actually editing stands out
(use-package solaire-mode
  :ensure t
  :config
  (solaire-global-mode +1))

;; consistent placement for REPL/shell/compile/help buffers, like Doom's
;; popup module, with a toggle/cycle instead of manual window management
(use-package popper
  :ensure t
  :bind (("C-`"   . popper-toggle)
         ("M-`"   . popper-cycle)
         ("C-M-`" . popper-toggle-type))
  :init
  (setq popper-reference-buffers
        '("\\*Messages\\*"
          "\\*Async Shell Command\\*"
          "^\\*shell:.*\\*$"
          "\\*sly-mrepl.*\\*"
          "\\*sly-started inferior-lisp.*\\*"
          help-mode
          compilation-mode
          vterm-mode))
  (popper-mode +1)
  (popper-echo-mode +1))

;;; ============================================================================
;;; FURTHER LINTING, SPELLCHECKING, ETC
;;; ============================================================================

; flycheck to check things
(use-package flycheck
  :init (global-flycheck-mode)
(setq-default flycheck-disabled-checkers '(tex-lacheck)) ; disabled because it is slowing down big files.
;; no Flycheck checker exists for Common Lisp; exclude to silence the "no syntax checker" message
(setq flycheck-global-modes '(not lisp-mode lisp-interaction-mode))

(add-hook 'text-mode-hook #'flyspell-mode)
(add-hook 'org-mode-hook #'flyspell-mode)
(add-hook 'markdown-mode-hook #'flyspell-mode)


(with-eval-after-load 'flycheck
  (flycheck-define-checker textlint "A linter for textlint."
			   :command ("npx" "--no-install" "textlint"
				     "--config" (eval
						 (let* ((project (project-current))
							(root (and project (project-root project)))
							(project-config
							 (and root
							      (expand-file-name ".textlintrc" root))))
						   (if (and project-config (file-exists-p project-config))
						       project-config
						     (expand-file-name ".textlintrc" user-emacs-directory))))
						 "--format" "unix"
						 "--plugin"
						 (eval
						  (if (derived-mode-p 'tex-mode)
						      "latex"
						    "@textlint/text"))
						 source-inplace)
				     :error-patterns
				     ((warning line-start (file-name) ":" line ":" column ": "
					       (message (one-or-more not-newline)
							(zero-or-more "\n" (any " ") (one-or-more not-newline)))
					       line-end))
				     :modes (text-mode latex-mode org-mode markdown-mode))
				     )
  (add-to-list 'flycheck-checkers 'textlint))

;;; ============================================================================
;;; LOAD SEPARATE CONFIG FILES
;;; ============================================================================

;; load org-mode config
(load (expand-file-name "org-config.el" user-emacs-directory))
