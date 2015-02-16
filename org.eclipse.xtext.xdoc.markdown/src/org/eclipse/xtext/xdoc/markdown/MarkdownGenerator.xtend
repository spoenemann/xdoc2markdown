/*******************************************************************************
 * Copyright (c) 2015 itemis AG (http://www.itemis.eu) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *******************************************************************************/
package org.eclipse.xtext.xdoc.markdown

import org.eclipse.xtext.generator.IGenerator
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.xdoc.xdoc.XdocFile
import org.eclipse.xtext.xdoc.xdoc.Document

class MarkdownGenerator implements IGenerator {
	
	override doGenerate(Resource input, IFileSystemAccess fsa) {
		val document = input.contents.filter(XdocFile).map[mainSection].filter(Document).head
		if (document != null) {
			fsa.generateFile('documentation.html', document.generate)
		}
	}
	
	private def generate(Document document) {
		'''
			---
			layout: page
			---
			
			Test
		'''
	}
	
}
