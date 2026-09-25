;; automatically wrap lines to fill-column while typing
(setq-default fill-column 100)
(add-hook 'org-mode-hook #'auto-fill-mode)

(use-package evil-org
    :ensure t
    :after org
    :diminish evil-org-mode
    :config
    (add-hook 'org-mode-hook #'evil-org-mode)
    (add-hook 'evil-org-mode-hook
	      (lambda ()
	      (evil-org-set-key-theme '(navigation insert textobjects additional calendar todo))))
    (require 'evil-org-agenda)
    (evil-org-agenda-set-keys))

;; nicer heading bullets/tables/tags/checkboxes than plain org-mode
(use-package org-modern
  :ensure t
  :after org
  :hook (org-mode . org-modern-mode))

(defun org-latex-preview-all()
  (interactive)
  (org-latex-preview '(16)))

(local-leader-def
  :keymaps 'org-mode-map
  "l" #'org-latex-preview-all
  :which-key "latex preview all")

(defun org-fill-buffer ()
  "Fill the buffer, skipping src/example/export/comment blocks."
  (interactive)
  (save-excursion
    (let ((case-fold-search t)
          (start (copy-marker (point-min)))
          (end-re "^[ \t]*#\\+end_\\(?:src\\|example\\|export\\|comment\\)")
          (begin-re "^[ \t]*#\\+begin_\\(?:src\\|example\\|export\\|comment\\)"))
      (goto-char (point-min))
      (while (re-search-forward begin-re nil t)
        (let ((block-beg (copy-marker (line-beginning-position))))
          (when (> block-beg start)
            (fill-region start block-beg))
          (if (re-search-forward end-re nil t)
              (progn (forward-line 1) (set-marker start (point)))
            (set-marker start (point-max))
            (goto-char (point-max)))))
      (when (< start (point-max))
        (fill-region start (point-max))))))

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

