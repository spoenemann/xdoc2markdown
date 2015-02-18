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
	
	private static val INDENT = '    '
	
	private static def ==(char c, CharSequence s) {
		s.length == 1 && c == s.charAt(0)
	}
	
	def +=(StringConcatenation concat, Object obj) {
		concat.append(obj)
		return concat
	}
	
	def ensureEmptyLine(StringConcatenation concat, int indent) {
		val s = concat.toString
		var lineBreaks = 0;
		for (var i = s.length - 1; i >= 0; i--) {
			val c = s.charAt(i)
			if (c == '\n') {
				lineBreaks++
				if (lineBreaks == 2)
					return concat
			} else if (!c.isWhitespace) {
				if (lineBreaks == 0) {
					if (!s.endsWith(INDENT))
						concat.indent(indent)
					concat.newLine
				}
				if (!s.endsWith(INDENT))
					concat.indent(indent)
				concat.newLine
				return concat
			}
		}
	}
	
	def ensureEmptyLine(StringConcatenation concat) {
		ensureEmptyLine(concat, 0)
	}
	
	def ensureSpace(StringConcatenation concat) {
		val s = concat.toString
		if (!s.empty && !s.charAt(s.length - 1).isWhitespace)
			concat += ' '
	}
	
	def indent(StringConcatenation concat, int n) {
		for (var i = 0; i < n; i++) {
			concat += INDENT
		}
	}
	
	def endsWithNewline(CharSequence s) {
		return s.length > 0 && s.charAt(s.length - 1) == '\n'
	}
	
	def startsWithWhitespace(CharSequence s) {
		return s.length > 0 && s.charAt(0).isWhitespace
	}
	
	def endsWithWhitespace(CharSequence s) {
		return s.length > 0 && s.charAt(s.length - 1).isWhitespace
	}
	
	def processEscapes(CharSequence s) {
		val result = new StringBuilder
		for (var i = 0; i < s.length; i++) {
			val c = s.charAt(i)
			if (c == '`')
				result.append('\\`')
			else if (c == '*')
				result.append('\\*')
			else if (c == '_')
				result.append('\\_')
			else if (c == '<')
				result.append('\\<')
			else if (c == '>')
				result.append('\\>')
			else
				result.append(c)
		}
		return result.toString
	}
	
}