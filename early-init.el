;;; ============================================================================
;;; EMACS CORE PERFORMANCE SETTINGS
;;; ============================================================================

;; Increase garbage collection threshold dramatically (default is ~800KB)
;; Set to 100MB during normal operation, 1GB during startup
(setq gc-cons-threshold 1000000000) ; 1 GB
(setq gc-cons-percentage 0.6)


;; Increase during startup, then reset
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold 100000000 ; 100 MB
                  gc-cons-percentage 0.1)))

(setq package-enable-at-startup nil)

(push '(tool-bar-lines . 0) default-frame-alist)
