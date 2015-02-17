/*******************************************************************************
 * Copyright (c) 2015 itemis AG (http://www.itemis.eu) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *******************************************************************************/
package org.eclipse.xtext.xdoc.markdown

import java.util.Map
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.generator.IGenerator
import org.eclipse.xtext.xdoc.xdoc.Anchor
import org.eclipse.xtext.xdoc.xdoc.Chapter
import org.eclipse.xtext.xdoc.xdoc.ChapterRef
import org.eclipse.xtext.xdoc.xdoc.Code
import org.eclipse.xtext.xdoc.xdoc.CodeBlock
import org.eclipse.xtext.xdoc.xdoc.Document
import org.eclipse.xtext.xdoc.xdoc.Emphasize
import org.eclipse.xtext.xdoc.xdoc.Identifiable
import org.eclipse.xtext.xdoc.xdoc.ImageRef
import org.eclipse.xtext.xdoc.xdoc.Link
import org.eclipse.xtext.xdoc.xdoc.OrderedList
import org.eclipse.xtext.xdoc.xdoc.PartRef
import org.eclipse.xtext.xdoc.xdoc.Ref
import org.eclipse.xtext.xdoc.xdoc.Section
import org.eclipse.xtext.xdoc.xdoc.Section2
import org.eclipse.xtext.xdoc.xdoc.Section2Ref
import org.eclipse.xtext.xdoc.xdoc.Section3
import org.eclipse.xtext.xdoc.xdoc.Section4
import org.eclipse.xtext.xdoc.xdoc.SectionRef
import org.eclipse.xtext.xdoc.xdoc.Table
import org.eclipse.xtext.xdoc.xdoc.TextOrMarkup
import org.eclipse.xtext.xdoc.xdoc.TextPart
import org.eclipse.xtext.xdoc.xdoc.Todo
import org.eclipse.xtext.xdoc.xdoc.UnorderedList
import org.eclipse.xtext.xdoc.xdoc.XdocFile
import java.util.HashSet
import java.util.HashMap

class MarkdownGenerator implements IGenerator {
	
	override doGenerate(Resource input, IFileSystemAccess fsa) {
		val document = input.contents.filter(XdocFile).map[mainSection].filter(Document).head
		if (document != null) {
			doGenerate(document, fsa)
		}
	}
	
	private def doGenerate(Document document, IFileSystemAccess fsa) {
		val idMap = document.createIdentifiableMap
		var i = 0
		for (ch : document.chapters) {
			val chapter = if (ch instanceof ChapterRef) ch.chapter else ch
			fsa.generateFile(getSourceFileName(chapter, i++), chapter.generate(document, idMap))
		}
		for (p : document.parts) {
			val part = if (p instanceof PartRef) p.part else p
			for (ch : part.chapters) {
				val chapter = if (ch instanceof ChapterRef) ch.chapter else ch
				fsa.generateFile(getSourceFileName(chapter, i++), chapter.generate(document, idMap))
			}
		}
	}
	
	private def createIdentifiableMap(Document document) {
		val result = new HashMap<Identifiable, String>
		var i = 0
		for (ch : document.chapters) {
			val chapter = if (ch instanceof ChapterRef) ch.chapter else ch
			val chapterFile = getTargetFileName(chapter, i++)
			result.put(chapter, chapterFile)
			chapter.eAllContents.filter(Identifiable).forEach[result.put(it, chapterFile)]
		}
		for (p : document.parts) {
			val part = if (p instanceof PartRef) p.part else p
			for (ch : part.chapters) {
				val chapter = if (ch instanceof ChapterRef) ch.chapter else ch
				val chapterFile = getTargetFileName(chapter, i++)
				result.put(chapter, chapterFile)
				chapter.eAllContents.filter(Identifiable).forEach[result.put(it, chapterFile)]
			}
		}
		return result
	}
	
	private def getSourceFileName(Chapter chapter, int index) {
		getBaseFileName(chapter, index) + '.md'
	}
	
	private def getTargetFileName(Chapter chapter, int index) {
		getBaseFileName(chapter, index) + '.html'
	}
	
	private def getBaseFileName(Chapter chapter, int index) {
		if (index == 0)
			'index'
		else if (index <= 9)
			'0' + index + '_' + chapter.name
		else
			index + '_' + chapter.name
	}
	
	private def generate(Chapter chapter, Document document, Map<Identifiable, String> idMap) {
		// TODO generate side bar for navigation
		val nextChapter = getNextChapter(chapter, idMap)
		'''
			---
			layout: page
			---
			
			# «if (chapter.name != null) '''<a name="«chapter.name»"/>'''»«chapter.title.generate(idMap)»
			
			«chapter.contents.map[generate(idMap)].join('\n')»
			
			«chapter.subSections.map[generate(idMap)].join('\n')»
			
			«if (nextChapter != null) '''[Next: «nextChapter.title.generate(idMap)»](«idMap.get(nextChapter)»)'''»
		'''
	}
	
	private def getNextChapter(Chapter chapter, Map<Identifiable, String> idMap) {
		val sortedChapters = new HashSet(idMap.values).sortWith[a, b |
			if (a.startsWith('index'))
				-1
			else if (b.startsWith('index'))
				1
			else
				a.compareTo(b)
		]
		val index = sortedChapters.indexOf(idMap.get(chapter))
		if (index + 1 < sortedChapters.size) {
			val nextChapterRef = sortedChapters.get(index + 1)
			val entry = idMap.entrySet.findFirst[key instanceof Chapter && value == nextChapterRef]
			return entry?.key as Chapter
		}
	}
	
	private def dispatch CharSequence generate(Object object, Map<Identifiable, String> idMap) {
		'''UNSUPPORTED XDOC FEATURE «object.class.simpleName»'''
	}
	
	private def dispatch CharSequence generate(Section section, Map<Identifiable, String> idMap) {
		'''
			## «if (section.name != null) '''<a name="«section.name»"/>'''»«section.title.generate(idMap)»
			
			«section.contents.map[generate(idMap)].join('\n')»
			
			«section.subSections.map[generate(idMap)].join('\n')»
		'''
	}
	
	private def dispatch CharSequence generate(SectionRef sectionRef, Map<Identifiable, String> idMap) {
		sectionRef.section.generate(idMap)
	}
	
	private def dispatch CharSequence generate(Section2 section, Map<Identifiable, String> idMap) {
		'''
			### «if (section.name != null) '''<a name="«section.name»"/>'''»«section.title.generate(idMap)»
			
			«section.contents.map[generate(idMap)].join('\n')»
			
			«section.subSections.map[generate(idMap)].join('\n')»
		'''
	}
	
	private def dispatch CharSequence generate(Section2Ref sectionRef, Map<Identifiable, String> idMap) {
		sectionRef.section2.generate(idMap)
	}
	
	private def dispatch CharSequence generate(Section3 section, Map<Identifiable, String> idMap) {
		'''
			#### «if (section.name != null) '''<a name="«section.name»"/>'''»«section.title.generate(idMap)»
			
			«section.contents.map[generate(idMap)].join('\n')»
			
			«section.subSections.map[generate(idMap)].join('\n')»
		'''
	}
	
	private def dispatch CharSequence generate(Section4 section, Map<Identifiable, String> idMap) {
		'''
			##### «if (section.name != null) '''<a name="«section.name»"/>'''»«section.title.generate(idMap)»
			
			«section.contents.map[generate(idMap)].join('\n')»
		'''
	}
	
	private def dispatch CharSequence generate(TextOrMarkup textOrMarkup, Map<Identifiable, String> idMap) {
		textOrMarkup.contents.map[generate(idMap)].join
	}
	
	private def dispatch CharSequence generate(TextPart textPart, Map<Identifiable, String> idMap) {
		textPart.text
	}
	
	private def dispatch CharSequence generate(Emphasize emphasize, Map<Identifiable, String> idMap) {
		'''_«emphasize.contents.map[generate(idMap)].join»_'''
	}
	
	private def dispatch CharSequence generate(Anchor anchor, Map<Identifiable, String> idMap) {
		'''<a name="«anchor.name»"/>'''
	}
	
	private def dispatch CharSequence generate(Ref ref, Map<Identifiable, String> idMap) {
		'''[«ref.contents.map[generate(idMap)].join»](«idMap.get(ref.ref)»#«ref.ref.name»)'''
	}
	
	private def dispatch CharSequence generate(OrderedList orderedList, Map<Identifiable, String> idMap) {
		orderedList.items.map['''1.  «contents.map[generate(idMap)].join»'''].join.toParagraph
	}
	
	private def dispatch CharSequence generate(UnorderedList unorderedList, Map<Identifiable, String> idMap) {
		unorderedList.items.map['''*   «contents.map[generate(idMap)].join»'''].join.toParagraph
	}
	
	private def dispatch CharSequence generate(CodeBlock codeBlock, Map<Identifiable, String> idMap) {
		if (codeBlock.isInlineCode)
			'''`«codeBlock.contents.get(0).generate(idMap)»`'''
		else
			'''    «codeBlock.contents.map[generate(idMap)].join»'''.toParagraph
	}
	
	private def isInlineCode(CodeBlock codeBlock) {
		if (codeBlock.contents.size == 1) {
			val content = codeBlock.contents.get(0)
			if (content instanceof Code) {
				return !content.contents.contains('\n')
			}
		} 
	}
	
	private def dispatch CharSequence generate(Code code, Map<Identifiable, String> idMap) {
		code.contents
	}
	
	private def dispatch CharSequence generate(Link link, Map<Identifiable, String> idMap) {
		'''[«link.text»](«link.url»)'''
	}
	
	private def dispatch CharSequence generate(ImageRef imageRef, Map<Identifiable, String> idMap) {
		'''![«imageRef.caption»](«imageRef.path»)'''.toParagraph
	}
	
	private def dispatch CharSequence generate(Todo todo, Map<Identifiable, String> idMap) {
		'''TODO «todo.text»'''
	}
	
	private def dispatch CharSequence generate(Table table, Map<Identifiable, String> idMap) {
		'''
			<table>
			    «table.rows.map['''
					<tr>
					    «data.map[
					  		'''<td>«contents.map[generate(idMap)].join»</td>'''
				  		].join('\n')»
					</tr>
		  		'''].join»
			</table>
		'''.toParagraph
	}
	
	private def toParagraph(CharSequence s) {
		'\n' + s + '\n'
	}
	
}
