/*******************************************************************************
 * Copyright (c) 2015 itemis AG (http://www.itemis.eu) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *******************************************************************************/
package org.eclipse.xtext.xdoc.markdown

import org.eclipse.xtend2.lib.StringConcatenation

import static extension java.lang.Character.*

/**
 * Extensions for {@link StringConcatenation}.
 */
class StringConcatenationExtensions {
	
	private static val NEWLINE_CHAR = '\n'.charAt(0)
	
	def +=(StringConcatenation concat, Object obj) {
		concat.append(obj)
		return concat
	}
	
	def ensureEmptyLine(StringConcatenation concat) {
		val s = concat.toString
		var lineBreaks = 0;
		for (var i = s.length - 1; i >= 0; i--) {
			val c = s.charAt(i)
			if (c == NEWLINE_CHAR) {
				lineBreaks++
				if (lineBreaks == 2)
					return concat
			} else if (!c.isWhitespace) {
				if (lineBreaks == 0)
					concat.newLine
				concat.newLine
				return concat
			}
		}
	}
	
	def ensureSpace(StringConcatenation concat) {
		val s = concat.toString
		if (!s.charAt(s.length - 1).isWhitespace)
			concat += ' '
	}
	
}