;; automatically wrap lines to fill-column while typing
(setq-default fill-column 80)
(add-hook 'org-mode-hook #'auto-fill-mode)

(use-package evil-org
    :ensure t
    :after org
    :diminish evil-org-mode
    :config
    (add-hook 'org-mode-hook #'evil-org-mode)
    ;; (add-hook 'evil-org-mode-hook
    ;; 	    (lambda ()
    ;; 	    (evil-org-set-key-theme)))
    (require 'evil-org-agenda)
    (evil-org-agenda-set-keys))

(defun org-latex-preview-all()
  (interactive)
  (org-latex-preview '(16)))

(local-leader-def
  :keymaps 'org-mode-map
  "l" #'org-latex-preview-all
  :which-key "latex preview all")

(defun org-fill-buffer ()
  (interactive)
  (fill-region (point-min) (point-max)))

(local-leader-def
  :keymaps 'org-mode-map
  "f" #'org-fill-buffer
  :which-key "fill buffer")

(defun org-toggle-window-wrap ()
  (interactive)
  (if visual-line-mode
      (visual-line-mode -1)
    (auto-fill-mode -1)
    (visual-line-mode 1)))

(local-leader-def
  :keymaps 'org-mode-map
  "w" #'org-toggle-window-wrap
  :which-key "toggle window-width wrap")

