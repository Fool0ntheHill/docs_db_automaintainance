#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
TKE 文档同步系统 - Markdown 内容提取器
将 HTML 内容转换为 Markdown 格式，保持文档结构和格式
"""

import re
from typing import Optional, List, Dict, Tuple
from bs4 import BeautifulSoup, Tag, NavigableString
from urllib.parse import urljoin, urlparse


class MarkdownContentExtractor:
    """Markdown 内容提取器"""
    
    def __init__(self, base_url: str = "https://cloud.tencent.com"):
        self.base_url = base_url
        self.list_counters = {}  # 用于跟踪有序列表的计数
        
    def extract_markdown_content(self, soup: BeautifulSoup, url: str) -> Optional[str]:
        """
        从 BeautifulSoup 对象中提取 Markdown 格式的内容
        
        Args:
            soup: BeautifulSoup 对象
            url: 原始 URL（用于处理相对链接）
            
        Returns:
            str: Markdown 格式的内容，失败时返回 None
        """
        # 主要选择器
        primary_selector = 'div.content-layout-container'
        
        # 备用选择器（按优先级排序）
        fallback_selectors = [
            'div.content-container',
            'div.main-content', 
            'article',
            'div.content',
            'main',
            'div#content'
        ]
        
        # 尝试主要选择器
        content_div = soup.find('div', class_='content-layout-container')
        if content_div:
            markdown = self._convert_to_markdown(content_div, url)
            if markdown and len(markdown.strip()) > 50:
                return self._clean_markdown(markdown)
        
        # 尝试备用选择器
        for selector in fallback_selectors:
            try:
                if '.' in selector:
                    class_name = selector.split('.')[1]
                    element = soup.find('div', class_=class_name)
                elif '#' in selector:
                    id_name = selector.split('#')[1]
                    element = soup.find('div', id=id_name)
                else:
                    element = soup.find(selector)
                
                if element:
                    markdown = self._convert_to_markdown(element, url)
                    if markdown and len(markdown.strip()) > 50:
                        return self._clean_markdown(markdown)
            except Exception as e:
                print(f"[Markdown提取] 备用选择器 {selector} 失败: {url} - {e}")
                continue
        
        # 最后尝试：提取 body 内容
        try:
            body = soup.find('body')
            if body:
                # 移除不需要的标签
                for tag in body(["script", "style", "nav", "header", "footer", "aside"]):
                    tag.decompose()
                
                markdown = self._convert_to_markdown(body, url)
                if markdown and len(markdown.strip()) > 100:
                    return self._clean_markdown(markdown)
        except Exception as e:
            print(f"[Markdown提取] body 内容提取失败: {url} - {e}")
        
        return None
    
    def _convert_to_markdown(self, element: Tag, url: str) -> str:
        """
        将 HTML 元素转换为 Markdown 格式
        
        Args:
            element: BeautifulSoup Tag 对象
            url: 原始 URL（用于处理相对链接）
            
        Returns:
            str: Markdown 格式的内容
        """
        markdown_parts = []
        self.list_counters = {}  # 重置列表计数器
        
        for child in element.children:
            if isinstance(child, Tag):
                md_content = self._process_tag(child, url)
                if md_content:
                    markdown_parts.append(md_content)
            elif isinstance(child, NavigableString):
                text = str(child).strip()
                if text:
                    markdown_parts.append(text)
        
        return '\n'.join(markdown_parts)
    
    def _process_tag(self, tag: Tag, url: str, list_level: int = 0) -> str:
        """
        处理单个 HTML 标签，转换为 Markdown
        
        Args:
            tag: BeautifulSoup Tag 对象
            url: 原始 URL
            list_level: 列表嵌套级别
            
        Returns:
            str: Markdown 格式的内容
        """
        tag_name = tag.name.lower()
        
        # 跳过不需要的标签
        if tag_name in ['script', 'style', 'nav', 'header', 'footer', 'aside']:
            return ""
        
        # 处理标题
        if tag_name in ['h1', 'h2', 'h3', 'h4', 'h5', 'h6']:
            level = int(tag_name[1])
            text = self._get_text_content(tag)
            return f"{'#' * level} {text}\n"
        
        # 处理段落
        elif tag_name == 'p':
            content = self._process_inline_content(tag, url)
            return f"{content}\n" if content.strip() else ""
        
        # 处理链接
        elif tag_name == 'a':
            return self._process_link(tag, url)
        
        # 处理强调
        elif tag_name in ['strong', 'b']:
            text = self._get_text_content(tag)
            return f"**{text}**"
        
        elif tag_name in ['em', 'i']:
            text = self._get_text_content(tag)
            return f"*{text}*"
        
        # 处理代码
        elif tag_name == 'code':
            text = self._get_text_content(tag)
            # 检查是否是行内代码还是代码块
            if '\n' in text or len(text) > 50:
                return f"```\n{text}\n```\n"
            else:
                return f"`{text}`"
        
        elif tag_name == 'pre':
            # 检查是否包含 code 标签
            code_tag = tag.find('code')
            if code_tag:
                text = self._get_text_content(code_tag)
                language = self._extract_language_from_code(code_tag)
                return f"```{language}\n{text}\n```\n"
            else:
                text = self._get_text_content(tag)
                return f"```\n{text}\n```\n"
        
        # 处理列表
        elif tag_name == 'ul':
            return self._process_unordered_list(tag, url, list_level)
        
        elif tag_name == 'ol':
            return self._process_ordered_list(tag, url, list_level)
        
        elif tag_name == 'li':
            return self._process_list_item(tag, url, list_level)
        
        # 处理引用
        elif tag_name == 'blockquote':
            content = self._process_inline_content(tag, url)
            lines = content.split('\n')
            quoted_lines = [f"> {line}" for line in lines if line.strip()]
            return '\n'.join(quoted_lines) + '\n'
        
        # 处理表格
        elif tag_name == 'table':
            return self._process_table(tag, url)
        
        # 处理图片
        elif tag_name == 'img':
            return self._process_image(tag, url)
        
        # 处理分隔线
        elif tag_name == 'hr':
            return "---\n"
        
        # 处理换行
        elif tag_name == 'br':
            return "\n"
        
        # 处理 div 和其他容器
        elif tag_name in ['div', 'section', 'article', 'main']:
            content_parts = []
            for child in tag.children:
                if isinstance(child, Tag):
                    child_content = self._process_tag(child, url, list_level)
                    if child_content:
                        content_parts.append(child_content)
                elif isinstance(child, NavigableString):
                    text = str(child).strip()
                    if text:
                        content_parts.append(text)
            
            result = '\n'.join(content_parts)
            return result + '\n' if result else ""
        
        # 默认处理：提取文本内容
        else:
            return self._process_inline_content(tag, url)
    
    def _process_inline_content(self, tag: Tag, url: str) -> str:
        """处理行内内容，保持格式"""
        content_parts = []
        
        for child in tag.children:
            if isinstance(child, Tag):
                child_content = self._process_tag(child, url)
                if child_content:
                    content_parts.append(child_content)
            elif isinstance(child, NavigableString):
                text = str(child).strip()
                if text:
                    content_parts.append(text)
        
        return ' '.join(content_parts)
    
    def _process_link(self, tag: Tag, url: str) -> str:
        """处理链接标签"""
        text = self._get_text_content(tag)
        href = tag.get('href', '')
        
        if not href:
            return text
        
        # 处理相对链接
        if href.startswith('/'):
            href = urljoin(self.base_url, href)
        elif not href.startswith(('http://', 'https://')):
            href = urljoin(url, href)
        
        return f"[{text}]({href})"
    
    def _process_image(self, tag: Tag, url: str) -> str:
        """处理图片标签"""
        alt = tag.get('alt', '')
        src = tag.get('src', '')
        
        if not src:
            return f"![{alt}]" if alt else ""
        
        # 处理相对链接
        if src.startswith('/'):
            src = urljoin(self.base_url, src)
        elif not src.startswith(('http://', 'https://')):
            src = urljoin(url, src)
        
        return f"![{alt}]({src})"
    
    def _process_unordered_list(self, tag: Tag, url: str, list_level: int) -> str:
        """处理无序列表"""
        items = []
        indent = "  " * list_level
        
        for li in tag.find_all('li', recursive=False):
            item_content = self._process_list_item(li, url, list_level)
            if item_content:
                items.append(f"{indent}- {item_content}")
        
        return '\n'.join(items) + '\n' if items else ""
    
    def _process_ordered_list(self, tag: Tag, url: str, list_level: int) -> str:
        """处理有序列表"""
        items = []
        indent = "  " * list_level
        counter = 1
        
        for li in tag.find_all('li', recursive=False):
            item_content = self._process_list_item(li, url, list_level)
            if item_content:
                items.append(f"{indent}{counter}. {item_content}")
                counter += 1
        
        return '\n'.join(items) + '\n' if items else ""
    
    def _process_list_item(self, tag: Tag, url: str, list_level: int) -> str:
        """处理列表项"""
        content_parts = []
        
        for child in tag.children:
            if isinstance(child, Tag):
                if child.name in ['ul', 'ol']:
                    # 嵌套列表
                    nested_content = self._process_tag(child, url, list_level + 1)
                    if nested_content:
                        content_parts.append('\n' + nested_content.rstrip())
                else:
                    child_content = self._process_tag(child, url, list_level)
                    if child_content:
                        content_parts.append(child_content.strip())
            elif isinstance(child, NavigableString):
                text = str(child).strip()
                if text:
                    content_parts.append(text)
        
        return ' '.join(content_parts)
    
    def _process_table(self, tag: Tag, url: str) -> str:
        """处理表格"""
        rows = []
        
        # 处理表头
        thead = tag.find('thead')
        if thead:
            header_row = thead.find('tr')
            if header_row:
                headers = []
                for th in header_row.find_all(['th', 'td']):
                    headers.append(self._get_text_content(th))
                
                if headers:
                    rows.append('| ' + ' | '.join(headers) + ' |')
                    rows.append('| ' + ' | '.join(['---'] * len(headers)) + ' |')
        
        # 处理表体
        tbody = tag.find('tbody') or tag
        for tr in tbody.find_all('tr'):
            cells = []
            for td in tr.find_all(['td', 'th']):
                cell_content = self._process_inline_content(td, url)
                cells.append(cell_content.replace('|', '\\|'))  # 转义管道符
            
            if cells:
                rows.append('| ' + ' | '.join(cells) + ' |')
        
        return '\n'.join(rows) + '\n' if rows else ""
    
    def _extract_language_from_code(self, code_tag: Tag) -> str:
        """从代码标签中提取语言信息"""
        # 检查 class 属性
        classes = code_tag.get('class', [])
        for cls in classes:
            if cls.startswith('language-'):
                return cls.replace('language-', '')
            elif cls.startswith('lang-'):
                return cls.replace('lang-', '')
        
        # 检查 data-lang 属性
        data_lang = code_tag.get('data-lang')
        if data_lang:
            return data_lang
        
        return ""
    
    def _get_text_content(self, tag: Tag) -> str:
        """获取标签的纯文本内容"""
        return tag.get_text(strip=True)
    
    def _clean_markdown(self, markdown: str) -> str:
        """
        清理 Markdown 内容
        
        Args:
            markdown: 原始 Markdown 内容
            
        Returns:
            str: 清理后的 Markdown 内容
        """
        if not markdown:
            return ""
        
        # 移除多余的空行
        lines = markdown.split('\n')
        cleaned_lines = []
        prev_empty = False
        
        for line in lines:
            line = line.rstrip()  # 移除行尾空白
            
            if line.strip() == "":
                if not prev_empty:  # 只保留一个空行
                    cleaned_lines.append("")
                    prev_empty = True
            else:
                cleaned_lines.append(line)
                prev_empty = False
        
        # 移除开头和结尾的空行
        while cleaned_lines and cleaned_lines[0] == "":
            cleaned_lines.pop(0)
        while cleaned_lines and cleaned_lines[-1] == "":
            cleaned_lines.pop()
        
        result = '\n'.join(cleaned_lines)
        
        # 修复一些常见的 Markdown 格式问题
        result = self._fix_markdown_formatting(result)
        
        return result
    
    def _fix_markdown_formatting(self, markdown: str) -> str:
        """修复常见的 Markdown 格式问题"""
        # 确保标题前后有空行
        markdown = re.sub(r'([^\n])\n(#{1,6}\s)', r'\1\n\n\2', markdown)
        markdown = re.sub(r'(#{1,6}[^\n]*)\n([^\n#])', r'\1\n\n\2', markdown)
        
        # 确保列表前后有空行
        markdown = re.sub(r'([^\n])\n(\s*[-*+]\s)', r'\1\n\n\2', markdown)
        markdown = re.sub(r'([^\n])\n(\s*\d+\.\s)', r'\1\n\n\2', markdown)
        
        # 确保代码块前后有空行
        markdown = re.sub(r'([^\n])\n(```)', r'\1\n\n\2', markdown)
        markdown = re.sub(r'(```[^\n]*)\n([^\n`])', r'\1\n\n\2', markdown)
        
        # 确保引用块前后有空行
        markdown = re.sub(r'([^\n])\n(>\s)', r'\1\n\n\2', markdown)
        
        # 修复连续的空行
        markdown = re.sub(r'\n{3,}', '\n\n', markdown)
        
        return markdown


def create_markdown_extractor(base_url: str = "https://cloud.tencent.com") -> MarkdownContentExtractor:
    """
    创建 Markdown 内容提取器实例
    
    Args:
        base_url: 基础 URL，用于处理相对链接
        
    Returns:
        MarkdownContentExtractor: 提取器实例
    """
    return MarkdownContentExtractor(base_url)