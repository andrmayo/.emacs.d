;; fill-column is used only by the explicit \f fill command (no auto-fill)
(setq-default fill-column 100)

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
  "Fill the buffer, skipping src/example/export/comment blocks and tables."
  (interactive)
  (save-excursion
    (let ((case-fold-search t)
          (begin-re "^[ \t]*#\\+begin_\\(?:src\\|example\\|export\\|comment\\)")
          (end-re "^[ \t]*#\\+end_\\(?:src\\|example\\|export\\|comment\\)")
          (skip-re "^[ \t]*\\(?:|\\|#\\+tblfm:\\)")
          (in-block nil)
          (start nil)
          regions)
      (goto-char (point-min))
      (while (not (eobp))
        (let ((skip (cond (in-block (when (looking-at end-re) (setq in-block nil)) t)
                          ((looking-at begin-re) (setq in-block t) t)
                          (t (looking-at skip-re)))))
          (cond ((and skip start)
                 (push (cons start (copy-marker (point))) regions)
                 (setq start nil))
                ((and (not skip) (not start))
                 (setq start (copy-marker (point))))))
        (forward-line 1))
      (when start (push (cons start (copy-marker (point-max))) regions))
      ;; regions is in reverse order, so filling proceeds back to front
      (dolist (r regions)
        (fill-region (car r) (cdr r))))))

(local-leader-def
  :keymaps 'org-mode-map
  "f" #'org-fill-buffer
  :which-key "fill buffer")

(defun org-toggle-auto-fill ()
  "Toggle `auto-fill-mode' and report the new state."
  (interactive)
  (auto-fill-mode 'toggle)
  (message "Auto-fill %s" (if auto-fill-function "enabled" "disabled")))

(local-leader-def
  :keymaps 'org-mode-map
  "F" #'org-toggle-auto-fill
  :which-key "toggle auto-fill")

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

