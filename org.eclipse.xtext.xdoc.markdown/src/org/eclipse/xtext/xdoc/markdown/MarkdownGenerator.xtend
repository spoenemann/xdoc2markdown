/*******************************************************************************
 * Copyright (c) 2015 itemis AG (http://www.itemis.eu) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *******************************************************************************/
package org.eclipse.xtext.xdoc.markdown

import java.util.HashMap
import java.util.HashSet
import java.util.List
import java.util.Map
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtend2.lib.StringConcatenation
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.generator.IGenerator
import org.eclipse.xtext.xdoc.xdoc.Anchor
import org.eclipse.xtext.xdoc.xdoc.Chapter
import org.eclipse.xtext.xdoc.xdoc.ChapterRef
import org.eclipse.xtext.xdoc.xdoc.Code
import org.eclipse.xtext.xdoc.xdoc.CodeBlock
import org.eclipse.xtext.xdoc.xdoc.CodeRef
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

import static extension java.lang.Character.*

class MarkdownGenerator implements IGenerator {
	
	private static val NEWLINE_CHAR = '\n'.charAt(0)
	
	private static def +=(StringConcatenation concat, Object obj) {
		concat.append(obj)
		return concat
	}
	
	private static def ensureEmptyLine(StringConcatenation concat) {
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
			fsa.generateFile(getSourceFileName(chapter, i++), chapter.doGenerate(document, idMap))
		}
		for (p : document.parts) {
			val part = if (p instanceof PartRef) p.part else p
			for (ch : part.chapters) {
				val chapter = if (ch instanceof ChapterRef) ch.chapter else ch
				fsa.generateFile(getSourceFileName(chapter, i++), chapter.doGenerate(document, idMap))
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
			'0' + index + '_' + chapter.name.toLowerCase
		else
			index + '_' + chapter.name.toLowerCase
	}
	
	private def doGenerate(Chapter chapter, Document document, Map<Identifiable, String> idMap) {
		val nextChapter = getNextChapter(chapter, idMap)
		val concat = new StringConcatenation('\n')
		concat += '''
			---
			layout: documentation
			---
		'''
		concat.newLine
		concat += '# '
		if (chapter.name != null)
			concat += '''<a name="«chapter.name»"/>'''
		chapter.title.generate(concat, idMap)
		
		concat.ensureEmptyLine
		chapter.contents.generateWithSeparation(concat, idMap)
		
		chapter.subSections.forEach[generate(concat, idMap)]
		
		if (nextChapter != null) {
			concat.ensureEmptyLine
			concat += '**[Next: '
			nextChapter.title.generate(concat, idMap)
			concat += '''](«idMap.get(nextChapter)»)**'''
		}
		return concat
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
	
	private def void generateWithSeparation(List<TextOrMarkup> contentList, StringConcatenation concat,
			Map<Identifiable, String> idMap) {
		contentList.forEach[ obj, i |
			if (i > 0)
				concat.ensureEmptyLine
			obj.generate(concat, idMap)
		]
	}
	
	private def dispatch void generate(Object object, StringConcatenation concat,
			Map<Identifiable, String> idMap) {
		concat += '''UNSUPPORTED XDOC FEATURE «object.class.simpleName»'''
	}
	
	private def dispatch void generate(Section section, StringConcatenation concat,
			Map<Identifiable, String> idMap) {
		concat.ensureEmptyLine
		concat += '## '
		if (section.name != null)
			concat += '''<a name="«section.name»"/>'''
		section.title.generate(concat, idMap)
		
		concat.ensureEmptyLine
		section.contents.generateWithSeparation(concat, idMap)
		
		section.subSections.forEach[generate(concat, idMap)]
	}
	
	private def dispatch void generate(SectionRef sectionRef, StringConcatenation concat,
			Map<Identifiable, String> idMap) {
		sectionRef.section.generate(concat, idMap)
	}
	
	private def dispatch void generate(Section2 section, StringConcatenation concat,
			Map<Identifiable, String> idMap) {
		concat.ensureEmptyLine
		concat += '### '
		if (section.name != null)
			concat += '''<a name="«section.name»"/>'''
		section.title.generate(concat, idMap)
		
		concat.ensureEmptyLine
		section.contents.generateWithSeparation(concat, idMap)
		
		section.subSections.forEach[generate(concat, idMap)]
	}
	
	private def dispatch void generate(Section2Ref sectionRef, StringConcatenation concat,
			Map<Identifiable, String> idMap) {
		sectionRef.section2.generate(concat, idMap)
	}
	
	private def dispatch void generate(Section3 section, StringConcatenation concat,
			Map<Identifiable, String> idMap) {
		concat.ensureEmptyLine
		concat += '#### '
		if (section.name != null)
			concat += '''<a name="«section.name»"/>'''
		section.title.generate(concat, idMap)
		
		concat.ensureEmptyLine
		section.contents.generateWithSeparation(concat, idMap)
		
		section.subSections.forEach[generate(concat, idMap)]
	}
	
	private def dispatch void generate(Section4 section, StringConcatenation concat,
			Map<Identifiable, String> idMap) {
		concat.ensureEmptyLine
		concat += '##### '
		if (section.name != null)
			concat += '''<a name="«section.name»"/>'''
		section.title.generate(concat, idMap)
		
		concat.ensureEmptyLine
		section.contents.generateWithSeparation(concat, idMap)
	}
	
	private def dispatch void generate(TextOrMarkup textOrMarkup, StringConcatenation concat,
			Map<Identifiable, String> idMap) {
		textOrMarkup.contents.forEach[generate(concat, idMap)]
	}
	
	private def dispatch void generate(TextPart textPart, StringConcatenation concat,
			Map<Identifiable, String> idMap) {
		concat += textPart.text
	}
	
	private def dispatch void generate(Emphasize emphasize, StringConcatenation concat,
			Map<Identifiable, String> idMap) {
		concat += '*'
		emphasize.contents.forEach[generate(concat, idMap)]
		concat += '*'
	}
	
	private def dispatch void generate(Anchor anchor, StringConcatenation concat,
			Map<Identifiable, String> idMap) {
		concat += '''<a name="«anchor.name»"/>'''
	}
	
	private def dispatch void generate(Ref ref, StringConcatenation concat,
			Map<Identifiable, String> idMap) {
		concat += '['
		ref.contents.forEach[generate(concat, idMap)]
		concat += '''](«idMap.get(ref.ref)»#«ref.ref.name»)'''
	}
	
	private def dispatch void generate(OrderedList orderedList, StringConcatenation concat,
			Map<Identifiable, String> idMap) {
		concat.ensureEmptyLine
		orderedList.items.forEach[
			concat += '1.  '
			contents.generateWithSeparation(concat, idMap)
		]
		concat.newLineIfNotEmpty
	}
	
	private def dispatch void generate(UnorderedList unorderedList, StringConcatenation concat,
			Map<Identifiable, String> idMap) {
		concat.ensureEmptyLine
		unorderedList.items.forEach[
			concat += '*   '
			contents.generateWithSeparation(concat, idMap)
		]
		concat.newLineIfNotEmpty
	}
	
	private def dispatch void generate(CodeBlock codeBlock, StringConcatenation concat,
			Map<Identifiable, String> idMap) {
		if (codeBlock.isInlineCode) {
			concat += '`'
			codeBlock.contents.get(0).generate(concat, idMap)
			concat += '`'
		} else {
			concat.ensureEmptyLine
			concat += '```'
			if (codeBlock.language != null)
				concat += codeBlock.language.name.toLowerCase
			codeBlock.contents.forEach[generate(concat, idMap)]
			concat += '```'
			concat.newLine
		}
	}
	
	private def isInlineCode(CodeBlock codeBlock) {
		if (codeBlock.contents.size == 1) {
			val content = codeBlock.contents.get(0)
			if (content instanceof Code) {
				return !content.contents.contains('\n')
			}
		}
	}
	
	private def dispatch void generate(Code code, StringConcatenation concat,
			Map<Identifiable, String> idMap) {
		concat += code.contents
	}
	
	private def dispatch void generate(Link link, StringConcatenation concat,
			Map<Identifiable, String> idMap) {
		concat += '''[«link.text»](«link.url»)'''
	}
	
	private def dispatch void generate(ImageRef imageRef, StringConcatenation concat,
			Map<Identifiable, String> idMap) {
		concat += '''![«imageRef.caption»](«imageRef.path»)'''
	}
	
	private def dispatch void generate(CodeRef codeRef, StringConcatenation concat,
			Map<Identifiable, String> idMap) {
		concat += '''codeRef:«codeRef.element.qualifiedName»'''
	}
	
	private def dispatch void generate(Todo todo, StringConcatenation concat,
			Map<Identifiable, String> idMap) {
		concat += '''TODO «todo.text»'''
	}
	
	private def dispatch void generate(Table table, StringConcatenation concat,
			Map<Identifiable, String> idMap) {
		if (!table.rows.empty) {
			concat.ensureEmptyLine
			concat += '|'
			table.rows.get(0).data.forEach[concat += '---|']
			table.rows.forEach[
				concat.newLine
				concat += '|'
				data.forEach[
			  		contents.generateWithSeparation(concat, idMap)
			  		concat += '|'
		  		]
			]
			concat.newLine
		}
	}
	
}
