;;; prv-emacs.el --- GNU Emacs specific code for preview.el

;; Copyright (C) 2001  Free Software Foundation, Inc.

;; Author: David Kastrup <David.Kastrup@t-online.de>
;; Keywords: convenience, tex, wp

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:

;; 

;;; Code:

(defvar preview-compatibility-macros nil
  "List of macros only present when compiling/loading.")

(defimage preview-nonready-icon ((:type xpm :file "prevwork.xpm" :ascent 90)
				 (:type xbm :file "prevwork.xbm" :ascent
					90))
  "The symbol used for previews to be generated.")

(defimage preview-error-icon ((:type xpm :file "preverr.xpm" :ascent 90)
			      (:type xbm :file "preverr.xbm" :ascent
				     90))
  "The symbol used for PostScript errors.")

(defimage preview-icon ((:type xpm :file "preview.xpm" :ascent 75)
			(:type xbm :file "preview.xbm" :ascent 75))
  "The symbol used for an open preview.")

(defcustom preview-transparent-color '(highlight :background)
  "Color to appear transparent in previews.
Set this to something unusual when using `preview-transparent-border',
to the default background in most other cases."
  :type '(radio (const :tag "None" nil)
		 (const :tag "Autodetect" t)
		 (color :tag "By name" :value "white")
		 (list :tag "Take from face"
		       :value (default :background)
		       (face)
		       (choice :tag "What to take"
			(const :tag "Background" :value :background)
			(const :tag "Foreground" :value :foreground))))
  :group 'preview-appearance)

(defcustom preview-transparent-border 1.5
  "Width of transparent border for previews in pt.
Setting this to a numeric value will add a border of
`preview-transparent-color' around images, and will turn
the heuristic-mask setting of images to default to 't since
then the borders are correctly detected even in case of
palette operations.  If the transparent color is something
not present otherwise in the image, the cursor display
will affect just this border.  A width of 0 is interpreted
by PostScript as meaning a single pixel, other widths are
interpreted as PostScript points (1/72 of 1in)"
  :group 'preview-appearance
  :type '(choice (const :value nil :tag "No border")
		 (number :value 1.5 :tag "Border width in pt")))

(defun preview-get-heuristic-mask ()
  "Get heuristic-mask to use for previews.
Consults `preview-transparent-color'."
  (cond ((stringp preview-transparent-color)
	 (color-values preview-transparent-color))
	((or (not (consp preview-transparent-color))
	     (integerp (car preview-transparent-color)))
	 preview-transparent-color)
	(t (color-values (preview-inherited-face-attribute
			  (nth 0 preview-transparent-color)
			  (nth 1 preview-transparent-color)
			  'default)))))

(defmacro preview-create-icon (file type ascent)
  "Create an icon from FILE, image TYPE and ASCENT."
  `(list 'image
	 :file ,file
	 :type ,type
	 :ascent ,ascent
	 :heuristic-mask (if preview-transparent-border t (preview-get-heuristic-mask))))

(defun preview-add-urgentization (fun ov &rest rest)
  "Cause FUN (function call form) to be called when redisplayed.
FUN must be a form with OV as first argument,
REST as the remainder, returning T."
  (let ((dispro (overlay-get ov 'display)))
    (unless (eq (car dispro) 'when)
      (overlay-put ov 'display `(when (,fun ,ov ,@rest)  . ,dispro)))))

(defun preview-remove-urgentization (ov)
  "Undo urgentization of OV by `preview-add-urgentization'.
Returns the old arguments to `preview-add-urgentization'
if there was any urgentization."
  (let ((dispro (overlay-get ov 'display)))
    (when (eq (car dispro) 'when)
      (prog1
	  (car (cdr dispro))
	  (overlay-put ov 'display (cdr (cdr dispro)))))))

(defmacro preview-nonready-copy ()
  "Prepare a later call of `preview-replace-active-icon'."

  ;; This is just a GNU Emacs specific efficiency hack because it
  ;; is easy to do.  When porting, don't do anything complicated
  ;; here, rather deliver just the unchanged icon and make
  ;; `preview-replace-active-icon' do the necessary work of replacing
  ;; the icon where it actually has been stored, probably
  ;; in the car of the strings property of the overlay.  This string
  ;; might probably serve as a begin-glyph as well, in which case
  ;; modifying the string in the strings property would change that
  ;; glyph automatically.

  '(cons 'image (cdr preview-nonready-icon)))

(defmacro preview-replace-active-icon (ov replacement)
  "Replace the active Icon in OV by REPLACEMENT, another icon."
  `(setcdr (overlay-get ,ov 'preview-image)
	   (cdr ,replacement)))

(defvar preview-button-1 [mouse-2])
(defvar preview-button-2 [mouse-3])

(defmacro preview-make-clickable (&optional map glyph helpstring click1 click2)
  "Generate a clickable string or keymap.
If MAP is non-nil, it specifies a keymap to add to, otherwise
a new one is created.  If GLYPH is given, the result is made
to display it, whether it is a string or image.  In that case,
HELPSTRING is a format string with one or two %s specifiers
for preview's clicks, displayed as a help-echo.  CLICK1 and CLICK2
are functions to call on preview's clicks."
  `(let (,@(if glyph `((res (if (stringp ,glyph)
				 (copy-sequence ,glyph)
			       (propertize "x" 'display ,glyph)))))
	   (resmap ,(or map '(make-sparse-keymap))))
     ,@(if click1
	   `((define-key resmap preview-button-1 ,click1)))
     ,@(if click2
	   `((define-key resmap preview-button-2 ,click2)))
     ,@(if glyph
	   `((add-text-properties
	      0 (length res)
	      (list 'mouse-face 'highlight
	      'help-echo (format ,helpstring preview-button-1 preview-button-2)
	      'keymap resmap)
	      res)
	     res)
	 '(resmap))))

(defun preview-int-bb (bb)
  "Make integer bounding box from possibly float BB."
  ;; Due to a bug in earlier Emacs versions, we make this a list instead
  ;; of a vector
  (when bb
    (list
     (floor (aref bb 0))
     (floor (aref bb 1))
     (ceiling (aref bb 2))
     (ceiling (aref bb 3)))))

(defun preview-ps-image (filename scale &optional box)
  "Place a PostScript image directly by Emacs.
This uses Emacs built-in PostScript image support for
rendering the preview image in EPS file FILENAME, with
a scale factor of SCALE indicating the relation of desired
image size on-screen to the size the PostScript code
specifies.  If BOX is present, it is the bounding box info."
  (unless box
    (setq box (preview-extract-bb filename)))
;; should the following 2 be rather intbb?
  (create-image filename 'postscript nil
		:pt-width (round
			   (* scale (- (aref box 2) (aref box 0))))
		:pt-height (round
			    (* scale (- (aref box 3) (aref box 1))))
		:bounding-box (preview-int-bb box)
		:ascent (preview-ascent-from-bb box)
		:heuristic-mask (if preview-transparent-border t (preview-get-heuristic-mask))))

(defvar preview-overlay nil)

(put 'preview-overlay
     'modification-hooks
     '(preview-handle-modification))

(put 'preview-overlay
     'insert-in-front-hooks
     '(preview-handle-insert-in-front))

(put 'preview-overlay
     'insert-behind-hooks
     '(preview-handle-insert-behind))

;; We have to fake our way around atomicity, but at least this is more
;; efficient than the XEmacs version which has to cope with not being
;; able to use local change hooks at all.

;; Here is the beef: for best intuitiveness, we want to have
;; insertions be carried out as expected before iconized text
;; passages, but we want to insert *into* the overlay when not
;; iconized.  A preview that has become empty can not get content
;; again: we remove it.  A disabled preview needs no insert-in-front
;; handler.

(defvar preview-change-list nil
  "List of tentatively changed overlays.")

(defun preview-register-change (ov)
  "Register not yet changed OV for verification.
This stores the old contents of the overlay in the
`preview-prechange' property and puts the overlay into
`preview-change-list' where `preview-check-changes' will
find it at some later point of time."
  (unless (overlay-get ov 'preview-prechange)
    (if (eq (overlay-get ov 'preview-state) 'disabled)
	(overlay-put ov 'preview-prechange t)
      (overlay-put ov 'preview-prechange
		   (save-restriction
		     (widen)
		     (buffer-substring-no-properties
		      (overlay-start ov) (overlay-end ov)))))
    (push ov preview-change-list)))

(defun preview-check-changes ()
  "Check whether the contents under the overlay have changed.
Disable it if that is the case.  Ignores text properties."
  (dolist (ov preview-change-list)
    (condition-case nil
	(with-current-buffer (overlay-buffer ov)
	  (let ((text (save-restriction
			(widen)
			(buffer-substring-no-properties
			 (overlay-start ov) (overlay-end ov)))))
	    (if (zerop (length text))
		(preview-delete ov)
	      (unless
		  (or (eq (overlay-get ov 'preview-state) 'disabled)
		      (string= text (overlay-get ov 'preview-prechange)))
		(overlay-put ov 'insert-in-front-hooks nil)
		(overlay-put ov 'insert-behind-hooks nil)
		(preview-disable ov)))))
      (error nil))
    (overlay-put ov 'preview-prechange nil))
  (setq preview-change-list nil))

(defun preview-handle-insert-in-front
  (ov after-change beg end &optional length)
  "Hook function for `insert-in-front-hooks' property.
See info node `(elisp) Overlay Properties' for
definition of OV, AFTER-CHANGE, BEG, END and LENGTH."
  (if after-change
      (unless undo-in-progress
	(if (eq (overlay-get ov 'preview-state) 'active)
	    (move-overlay ov end (overlay-end ov))))
    (preview-register-change ov)))

(defun preview-handle-insert-behind
  (ov after-change beg end &optional length)
  "Hook function for `insert-behind-hooks' property.
This is needed in case `insert-before-markers' is used at the
end of the overlay.  See info node `(elisp) Overlay Properties'
for definition of OV, AFTER-CHANGE, BEG, END and LENGTH."
  (if after-change
      (unless undo-in-progress
	(if (eq (overlay-get ov 'preview-state) 'active)
	    (move-overlay ov (overlay-start ov) beg)))
    (preview-register-change ov)))

(defun preview-handle-modification
  (ov after-change beg end &optional length)
  "Hook function for `modification-hooks' property.
See info node `(elisp) Overlay Properties' for
definition of OV, AFTER-CHANGE, BEG, END and LENGTH."
  (unless after-change
    (preview-register-change ov)))

(defun preview-toggle (ov &optional arg)
  "Toggle visibility of preview overlay OV.
ARG can be one of the following: t displays the overlay,
nil displays the underlying text, and 'toggle toggles."
  (let ((old-urgent (preview-remove-urgentization ov))
	(preview-state
	 (if (if (eq arg 'toggle)
		 (null (eq (overlay-get ov 'preview-state) 'active))
	       arg)
	     'active
	   'inactive))
	(strings (overlay-get ov 'strings)))
    (unless (eq (overlay-get ov 'preview-state) 'disabled)
      (overlay-put ov 'preview-state preview-state)
      (if (eq preview-state 'active)
	  (progn
	    (overlay-put ov 'category 'preview-overlay)
	    (if (eq (overlay-start ov) (overlay-end ov))
		(overlay-put ov 'before-string (car strings))
	      (dolist (prop '(display keymap mouse-face help-echo))
		(overlay-put ov prop
			     (get-text-property 0 prop (car strings))))
	      (overlay-put ov 'before-string nil))
	    (overlay-put ov 'face nil))
	(dolist (prop '(display keymap mouse-face help-echo))
	  (overlay-put ov prop nil))
	(overlay-put ov 'face 'preview-face)
	(overlay-put ov 'before-string (cdr strings)))
      (if old-urgent
	  (apply 'preview-add-urgentization old-urgent)))))

(defun preview-mode-setup ()
  "Setup proper buffer hooks and behavior for previews."
  (add-hook 'pre-command-hook #'preview-mark-point nil t)
  (add-hook 'post-command-hook #'preview-move-point nil t))


(defvar preview-marker (make-marker)
  "Marker for fake intangibility.")

(defvar preview-temporary-opened nil)

(defun preview-mark-point ()
  "Mark position for fake intangibility."
;;  seems to hurt more than it helps.
;;  (when (eq (get-char-property (point) 'preview-state) 'active)
;;    (set-marker preview-marker (point))
;;    (preview-move-point))
  (set-marker preview-marker (point)))

(defcustom preview-auto-reveal 'reveal-mode
  "*Cause previews to open automatically when entered.
Set to t or nil, or to a symbol which will be consulted
if defined.  The default is to follow the setting of
`reveal-mode'."
  :group 'preview-appearance
  :type '(choice (const :tag "Off" nil)
		 (const :tag "On" t)
		 symbol))

(defun preview-move-point ()
  "Move point out of fake-intangible areas."
  (preview-check-changes)
  (let (newlist (pt (point)))
    (setq preview-temporary-opened
	  (dolist (ov preview-temporary-opened newlist)
	    (if (catch 'keep
		  (unless (and (overlay-buffer ov)
			       (eq (overlay-get ov 'preview-state) 'inactive))
		    (throw 'keep nil))
		  (unless (eq (overlay-buffer ov) (current-buffer))
		    (throw 'keep t))
		  (when (and (> pt (overlay-start ov))
			     (< pt (overlay-end ov)))
		    (throw 'keep t))
		  (preview-toggle ov t)
		  nil)
		(push ov newlist))))
    (if (or disable-point-adjustment
	    global-disable-point-adjustment
	    (and (boundp preview-auto-reveal)
		 (symbol-value preview-auto-reveal)))
	(preview-open-overlays (overlays-at pt))
      (let ((backward (and (eq (marker-buffer preview-marker) (current-buffer))
			   (< pt (marker-position preview-marker)))))
	(while (catch 'loop
		 (dolist (ovr (overlays-at pt))
		   (when (and
			  (eq (overlay-get ovr 'preview-state) 'active)
			  (> pt (overlay-start ovr)))
		     (setq pt (if backward
				  (overlay-start ovr)
				(overlay-end ovr)))
		     (throw 'loop t))))
	  nil)
	(goto-char pt)))))

(defun preview-open-overlays (list &optional pos)
  "Open all previews in LIST, optionally restricted to enclosing POS."
  (dolist (ovr list)
    (when (and (eq (overlay-get ovr 'preview-state) 'active)
	       (or (null pos)
		   (and
		    (> pos (overlay-start ovr))
		    (< pos (overlay-end ovr)))))
      (preview-toggle ovr)
      (push ovr preview-temporary-opened))))

(defadvice replace-highlight (before preview)
  "Make `query-replace' open preview text about to be replaced."
  (preview-open-overlays
   (overlays-in (ad-get-arg 0) (ad-get-arg 1))))

(defcustom preview-query-replace-reveal t
  "*Make `query-replace' autoreveal previews."
  :group 'preview-appearance
  :type 'boolean
  :require 'preview
  :set (lambda (symbol value)
	 (set-default symbol value)
	 (if value
	     (ad-enable-advice 'replace-highlight 'before 'preview)
	   (ad-disable-advice 'replace-highlight 'before 'preview))
	 (ad-activate 'replace-highlight))
  :initialize #'custom-initialize-reset)

(defun preview-gs-color-value (value)
  "Return string to be used as color value for an RGB component.
Conversion from Emacs color numbers (0 to 65535) in VALUE
to GhostScript floats."
  (format "%g" (/ value 65535.0)))

(defun preview-inherited-face-attribute (face attribute &optional
					      fallbacks)
  "Fetch face attribute while adhering to inheritance.
This searches FACE for an ATTRIBUTE.  If it is 'unspecified,
first inheritance is consulted (if FALLBACKS is non-NIL), then
FALLBACKS is searched if it is a face or a list of faces.
Relative specs are evaluated recursively until they get absolute or
are not resolvable.  Relative specs are float values."
  (let ((value (face-attribute face attribute)))
    (when fallbacks
      (setq fallbacks
	    (append
	     (let ((ancestors (face-attribute face :inherit)))
	       (cond ((facep ancestors) (list ancestors))
		     ((consp ancestors) ancestors)))
	     (cond ((facep fallbacks) (list fallbacks))
		   ((consp fallbacks) fallbacks)))))
    (cond ((null fallbacks) value)
	  ((floatp value)
	   (let ((avalue
		  (preview-inherited-face-attribute
		   (car fallbacks) attribute (or (cdr fallbacks) t))))
	     (cond ((integerp avalue)
		    (round (* avalue value)))
		   ((floatp avalue)
		    (* value avalue))
		   (t value))))
	  ((eq value 'unspecified)
	   (preview-inherited-face-attribute
	    (car fallbacks) attribute (or (cdr fallbacks) t)))
	  (t value))))

(defun preview-gs-get-colors ()
  "Return color setup tokens for GhostScript.
Fetches the current screen colors and makes a list of tokens
suitable for passing into GhostScript as arguments.
Pure borderless black-on-white will return NIL."
  (let
      ((bg (color-values (preview-inherited-face-attribute
			  'preview-reference-face :background 'default)))
       (fg (color-values (preview-inherited-face-attribute
			  'preview-reference-face :foreground 'default)))
       (mask (preview-get-heuristic-mask)))
    (if (equal '(65535 65535 65535) bg)
	(setq bg nil))
    (if (equal '(0 0 0) fg)
	(setq fg nil))
    (unless (and (numberp preview-transparent-border)
		 (consp mask) (integerp (car mask)))
      (setq mask nil))
    (append
     (if (or mask (and bg (not fg)))
	 '("gsave"))
     (if bg
	 (append
	  (mapcar #'preview-gs-color-value bg)
	  '("setrgbcolor" "clippath" "fill")))
     (if mask
	 (append
	  (mapcar #'preview-gs-color-value mask)
	  '("setrgbcolor" "false" "setstrokeadjust")
	  (list (number-to-string (* 2 preview-transparent-border)))
	  '("setlinewidth" "clippath" "strokepath" "fill")))
     (if (or mask (and bg (not fg)))
	 '("grestore"))
     (if fg
	 (append
	  (mapcar #'preview-gs-color-value fg)
	  '("setrgbcolor"))))))

(defmacro preview-mark-active ()
  "Return t if the mark is active."
  'mark-active)

(defmacro preview-with-LaTeX-menus (&rest bodyforms)
  "Activates the LaTeX menus for the BODYFORMS.
This makes it possible to add to them."
  `(let ((save-map (current-local-map)))
     (unwind-protect
	 (progn
	   (use-local-map LaTeX-mode-map) ,@bodyforms)
       (use-local-map save-map))))

(defmacro preview-export-image (image)
  image)

(defmacro preview-import-image (image)
  image)

(provide 'prv-emacs)
;;; prv-emacs.el ends here
