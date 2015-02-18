/*******************************************************************************
 * Copyright (c) 2015 itemis AG (http://www.itemis.eu) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *******************************************************************************/
package org.eclipse.xtext.xdoc.markdown

import org.eclipse.xtend2.lib.StringConcatenation

/**
 * A customized string concatenation that does not ignore trailing whitespace in its output.
 */
class MyStringConcatenation extends StringConcatenation {
	
	new() {
	}
	
	new(String lineDelimiter) {
		super(lineDelimiter)
	}
	
	override protected getSignificantContent() {
		// This method is available since Xtext 2.8.0
		content
	}
	
}