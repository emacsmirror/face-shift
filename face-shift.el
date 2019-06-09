;;; -*- lexical-binding: t -*-
;;; published under CC0 into the public domain
;;; author: philip k. [https://zge.us.to], 2019

(require 'color)
(eval-when-compile (require 'cl-lib))

(defgroup face-shift nil
  "Distort colours of certain faces"
  :group 'faces
  :prefix "face-shift-")

(defcustom face-shift-force-fit nil
  "Make sure that all transformations stay in the RGB-unit-space,
by wrapping values over 1 to 1."
  :type 'boolean
  :group 'face-shift)

(defcustom face-shift-intensity 0.9
  "Value to replace a `int' symbol with in `face-shift-colors'."
  :type 'float
  :group 'face-shift)

(defcustom face-shift-minimum 0.0
  "Value to replace a `min' symbol with in `face-shift-colors'."
  :type 'float
  :group 'face-shift)

(defcustom face-shift-maximum 1.0
  "Value to replace a `max' symbol with in `face-shift-colors'."
  :type 'float
  :group 'face-shift)

(defcustom face-shift-colors
  '((blue .   ((int min min) (min max min) (min min max)))
	(pink .   ((max min min) (min int min) (min min max)))
	(yellow . ((max min min) (min max min) (min min int)))
	(peach .  ((max min min) (min int min) (min min int)))
	(green .  ((int min min) (min max min) (min min int)))
	(purple . ((int min min) (min int min) (min min max))))
  "Alist of matrices representing RGB transformations towards a
  certain hue. Symbols `int', `max' and `min' are substituted
  with `face-shift-intensity', `face-shift-maximum' and
  `face-shift-minimum' respectively."
  :type '(list (list symbol))
  :group 'face-shift)

(defcustom face-shift-faces
  (append '(default cursor region isearch)
		  (cl-remove-if-not
		   (lambda (sym)
			 (string-match-p (rx bos "font-lock-")
							 (symbol-name sym)))
		   (face-list)))
  "Faces that `face-shift' should distort."
  :type '(list face)
  :group 'face-shift)

(defun face-shift-by (face prop mat)
  "Call `face-remap-add-relative' on FACE by distorting the
colour behind PROP by MAT in an RGB colour space."
  (let* ((mvp (lambda (vec)
				(mapcar (lambda (row)
						  (apply #'+ (cl-mapcar #'* row vec)))
						mat)))
		 (bg (face-attribute face prop))
		 (colors (color-name-to-rgb bg))
		 (trans (funcall mvp colors))
		 (ncolor
		  (apply
		   #'color-rgb-to-hex
		   (append
			(if face-shift-force-fit
				(mapcar (lambda (x) (if (< x 1) 1 x))
						trans)
			  trans)
			'(2)))))
	(unless (eq bg 'unspecified)
	  (face-remap-add-relative face `(,prop ,ncolor)))
	ncolor))

(defun face-shift (color &optional ignore)
  "Produce a function that will shift all background and
foreground colours behind the faces listed in `face-shift-faces',
that can then be added to a hook. COLOR should index a
transformation from the `face-shift-colors' alist.

If IGNORE is non-nil, it has to be a list of modes that should be
ignored by this hook. For example

   (face-shift 'green '(mail-mode))

will apply the green shift, unless the mode of the hook it was
added to is mail-mode or a derivative."
  (let ((mat (cl-sublis
			  `((int . ,face-shift-intensity)
				(max . ,face-shift-maximum)
				(min . ,face-shift-minimum))
			  (cdr (assq color face-shift-colors)))))
	(lambda ()
	  (unless (cl-some #'derived-mode-p ignore)
		(dolist (face face-shift-faces)
		  (face-shift-by face :foreground mat)
		  (face-shift-by face :background mat))))))

(provide 'face-shift)
