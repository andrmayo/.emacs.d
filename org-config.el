(defun org-latex-preview-all()
  (interactive)
  (org-latex-preview '(16)))

(local-leader-def
  :keymaps 'org-mode-map
  "l" #'org-latex-preview-all)

