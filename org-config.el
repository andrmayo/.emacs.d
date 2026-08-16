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
  "l" #'org-latex-preview-all)

