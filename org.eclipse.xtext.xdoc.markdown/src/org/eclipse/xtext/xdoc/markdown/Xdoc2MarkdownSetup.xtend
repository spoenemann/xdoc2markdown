/*******************************************************************************
 * Copyright (c) 2015 itemis AG (http://www.itemis.eu) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *******************************************************************************/
package org.eclipse.xtext.xdoc.markdown

import com.google.inject.Guice
import org.eclipse.xtext.xdoc.XdocRuntimeModule
import org.eclipse.xtext.xdoc.XdocStandaloneSetup

class Xdoc2MarkdownSetup extends XdocStandaloneSetup {
	
	override createInjector() {
		Guice.createInjector(new Xdoc2MarkdownModule)
	}
	
	static class Xdoc2MarkdownModule extends XdocRuntimeModule {
		override bindIGenerator() {
			MarkdownGenerator
		}
	}
	
}