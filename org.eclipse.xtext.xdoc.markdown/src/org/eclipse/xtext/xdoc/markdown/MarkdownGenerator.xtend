/*******************************************************************************
 * Copyright (c) 2015 itemis AG (http://www.itemis.eu) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *******************************************************************************/
package org.eclipse.xtext.xdoc.markdown

import com.google.inject.Inject
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
import org.eclipse.emf.ecore.util.EcoreUtil
import com.google.common.base.Strings

/**
 * An Xdoc generator that produces GitHub Flavored Markdown.
 */
class MarkdownGenerator implements IGenerator {
	
	@Inject extension StringConcatenationExtensions
	
	@Inject extension GitExtensions
	
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
			val sourceFileName = getSourceFileName(chapter, i++)
			fsa.generateFile(sourceFileName, chapter.generate(idMap))
			println('Generated ' + sourceFileName)
		}
		for (p : document.parts) {
			val part = if (p instanceof PartRef) p.part else p
			for (ch : part.chapters) {
				val chapter = if (ch instanceof ChapterRef) ch.chapter else ch
				val sourceFileName = getSourceFileName(chapter, i++)
				fsa.generateFile(sourceFileName, chapter.generate(idMap))
				println('Generated ' + sourceFileName)
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
	
	private def CharSequence generate(Chapter chapter, Map<Identifiable, String> idMap) {
		val nextChapter = getNextChapter(chapter, idMap)
		val concat = new MyStringConcatenation('\n')
		concat += '''
			---
			layout: documentation
			---
		'''
		concat.newLine
		concat += '# '
		chapter.title.generate(concat, 0, idMap)
		if (chapter.name != null)
			concat += ''' {#«chapter.name.trim»}'''
		
		concat.ensureEmptyLine
		chapter.contents.generateWithSeparation(concat, 0, idMap)
		
		chapter.subSections.forEach[generate(concat, idMap)]
		
		if (nextChapter != null) {
			concat.ensureEmptyLine
			concat += '---'
			concat.newLine
			concat.newLine
			concat += '**[Next Chapter: '
			nextChapter.title.generate(concat, 0, idMap)
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
	
	private def dispatch void generate(Section section, StringConcatenation concat,
			Map<Identifiable, String> idMap) {
		concat.ensureEmptyLine
		concat += '## '
		section.title.generate(concat, 0, idMap)
		if (section.name != null)
			concat += ''' {#«section.name.trim»}'''
		
		concat.ensureEmptyLine
		section.contents.generateWithSeparation(concat, 0, idMap)
		
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
		section.title.generate(concat, 0, idMap)
		if (section.name != null)
			concat += ''' {#«section.name.trim»}'''
		
		concat.ensureEmptyLine
		section.contents.generateWithSeparation(concat, 0, idMap)
		
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
		section.title.generate(concat, 0, idMap)
		if (section.name != null)
			concat += ''' {#«section.name.trim»}'''
		
		concat.ensureEmptyLine
		section.contents.generateWithSeparation(concat, 0, idMap)
		
		section.subSections.forEach[generate(concat, idMap)]
	}
	
	private def dispatch void generate(Section4 section, StringConcatenation concat,
			Map<Identifiable, String> idMap) {
		concat.ensureEmptyLine
		concat += '##### '
		section.title.generate(concat, 0, idMap)
		if (section.name != null)
			concat += ''' {#«section.name.trim»}'''
		
		concat.ensureEmptyLine
		section.contents.generateWithSeparation(concat, 0, idMap)
	}
	
	private def void generateWithSeparation(List<TextOrMarkup> contentList, StringConcatenation concat, int indent,
			Map<Identifiable, String> idMap) {
		contentList.forEach[ obj, i |
			if (i > 0)
				concat.ensureEmptyLine(indent)
			obj.generate(concat, indent, idMap)
		]
	}
	
	private def dispatch void generate(Object object, StringConcatenation concat, int indent,
			Map<Identifiable, String> idMap) {
		concat += '''UNSUPPORTED XDOC FEATURE «object.class.simpleName»'''
	}
	
	private def dispatch void generate(TextOrMarkup textOrMarkup, StringConcatenation concat, int indent,
			Map<Identifiable, String> idMap) {
		textOrMarkup.contents.forEach[
			if (concat.endsWithNewline)
				concat.indent(indent)
			generate(concat, indent, idMap)
		]
	}
	
	private def dispatch void generate(TextPart textPart, StringConcatenation concat, int indent,
			Map<Identifiable, String> idMap) {
		if (textPart.text != null && !textPart.text.trim.empty) {
			if (textPart.text.startsWithWhitespace && !concat.endsWithWhitespace)
				concat += ' '
			concat += textPart.text.trim.replaceAll('\\s+', ' ').processEscapes
			if (textPart.text.endsWithWhitespace)
				concat += ' '
		}
	}
	
	private def dispatch void generate(Emphasize emphasize, StringConcatenation concat, int indent,
			Map<Identifiable, String> idMap) {
		concat += '**'
		emphasize.contents.forEach[generate(concat, indent, idMap)]
		concat += '**'
	}
	
	private def dispatch void generate(Anchor anchor, StringConcatenation concat, int indent,
			Map<Identifiable, String> idMap) {
		concat += '''<a name="«anchor.name?.trim»"/>'''
	}
	
	private def dispatch void generate(Ref ref, StringConcatenation concat, int indent,
			Map<Identifiable, String> idMap) {
		concat += '['
		ref.contents.forEach[generate(concat, indent, idMap)]
		concat += ']('
		concat += idMap?.get(ref.ref)
		if (!(ref.ref instanceof Chapter) || EcoreUtil.isAncestor(ref.ref, ref)) {
			concat += '#'
			concat += ref.ref.name?.trim
		}
		concat += ')'
	}
	
	private def dispatch void generate(OrderedList orderedList, StringConcatenation concat, int indent,
			Map<Identifiable, String> idMap) {
		concat.ensureEmptyLine(indent)
		orderedList.items.forEach[
			concat.indent(indent)
			concat += '1.  '
			contents.generateWithSeparation(concat, indent + 1, idMap)
			concat.newLineIfNotEmpty
		]
		concat.ensureEmptyLine
	}
	
	private def dispatch void generate(UnorderedList unorderedList, StringConcatenation concat, int indent,
			Map<Identifiable, String> idMap) {
		concat.ensureEmptyLine(indent)
		unorderedList.items.forEach[
			concat.indent(indent)
			concat += '*   '
			contents.generateWithSeparation(concat, indent + 1, idMap)
			concat.newLineIfNotEmpty
		]
		concat.ensureEmptyLine
	}
	
	private def dispatch void generate(CodeBlock codeBlock, StringConcatenation concat, int indent,
			Map<Identifiable, String> idMap) {
		if (codeBlock.isInlineCode) {
			concat += '`'
			codeBlock.contents.forEach[generate(concat, indent, idMap)]
			concat += '`'
		} else {
			concat.ensureEmptyLine(indent)
			concat.indent(indent)
			concat += '```'
			if (codeBlock.language != null)
				concat += codeBlock.language.name.toLowerCase
			val codeConcat = new MyStringConcatenation('\n')
			codeBlock.contents.forEach[generate(codeConcat, indent, idMap)]
			if (!codeConcat.startsWithNewline)
				concat.newLine
			val codeIndent = 4 * indent - codeConcat.indentationAmount
			if (codeIndent > 0)
				concat.append(codeConcat, Strings.repeat(' ', codeIndent))
			else
				concat.append(codeConcat)
			concat.newLineIfNotEmpty
			if (indent > 0 && concat.endsWithNewline)
				concat.indent(indent)
			concat += '```'
			concat.ensureEmptyLine
		}
	}
	
	private def isInlineCode(CodeBlock codeBlock) {
		codeBlock.contents.forall[it instanceof Code] && codeBlock.contents.map[it as Code].forall[!contents.contains('\n')]
	}
	
	private def dispatch void generate(Code code, StringConcatenation concat, int indent,
			Map<Identifiable, String> idMap) {
		concat += code.contents.replace('\\[', '[').replace('\\]', ']')
	}
	
	private def dispatch void generate(Link link, StringConcatenation concat, int indent,
			Map<Identifiable, String> idMap) {
		concat += '''[«link.text?.trim?.replaceAll('\\s+', ' ')»](«link.url?.trim»)'''
	}
	
	private def dispatch void generate(ImageRef imageRef, StringConcatenation concat, int indent,
			Map<Identifiable, String> idMap) {
		concat += '''![«imageRef.caption?.trim?.replaceAll('\\s+', ' ')»](«imageRef.path?.trim»)'''
	}
	
	private def dispatch void generate(CodeRef codeRef, StringConcatenation concat, int indent,
			Map<Identifiable, String> idMap) {
		concat += '['
		if (codeRef.altText == null)
			concat += codeRef.element.simpleName
		else
			codeRef.altText.generate(concat, indent, idMap)
		concat += '''](«codeRef.element.gitLink»)'''
	}
	
	private def dispatch void generate(Todo todo, StringConcatenation concat, int indent,
			Map<Identifiable, String> idMap) {
		concat.newLineIfNotEmpty
		concat += '''TODO «todo.text?.trim»'''
		concat.newLine
	}
	
	private def dispatch void generate(Table table, StringConcatenation concat, int indent,
			Map<Identifiable, String> idMap) {
		if (!table.rows.empty) {
			concat.ensureEmptyLine(indent)
			concat.indent(indent)
			concat += '|'
			table.rows.get(0).data.forEach[concat += ':---|']
			table.rows.forEach[
				concat.newLine
				concat.indent(indent)
				concat += '|'
				data.forEach[
			  		contents.generateWithSeparation(concat, indent, idMap)
			  		concat += '|'
		  		]
			]
			concat.ensureEmptyLine
		}
	}
	
}
