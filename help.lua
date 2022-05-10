#!/usr/bin/env lua
local luaversion = _VERSION:match'%d%.%d':gsub('%.', '')
local pathsep = '\\'
local P = print
local F = function (s, ...) print((...) and s:format(...) or s) end
local K = function (s, ...) print('>>'..((...) and s:format(...) or s)..'<<') end
local function tabstr(t) 
	local b = {}
	for k,v in pairs(t) do
		table.insert(b, k..' = '..tostring(v))
	end
	return(b[1] and table.concat(b, ', ') or '<Table empty>')
end
local T = function (t) print(tabstr(t)) end
local D = function () print('DEBUG: '..tostring(tabstr(debug.getinfo(2, 'l')))) end

local C = {
	manualmodname = 'help_manual',
	configmodname = 'help_config',
 	highlight = '*',
	useconsole = true;
	console = {
		pagescroll = 1;
		word = 'red', title = 'cyan', matchnumber = 'red', wait = 'brown'; 
	},
	indent = 8, 
	maxcolumn = 80, -- Determines where lines will be wrapped.
	showsize = 1, -- Total number of lines to show for a match.
	versions = '51en 52en',
 	language = 'en',
	helpnamedefault = 'h',
	helpname = nil,
	initialpage = 20,
	pagescroll = 20,
	listbullet = '-',
	pgspace = true,
 	matchnumber = '%i*', 
 	exitword = 'quit',
 	iomode = 'io',	
}

local S = {
	help_usage = [[help (word1, word2, ...) or: help'word1 word2 ...'
	Search the lua manual for the given words. 
	If only one argument is given then it is split on spaces to produce separate words, so that the second shorter form may be used.
	Quotes in words are ignored (but matched). A hyphen '-' separating 2 words also matches a space.
	So, to have spaces in words either use the first form, or use the hyphen instead of space.
	Words are taken literally, lua string patterns are not interpreted.
	If the first word is one of the following names, the search is restricted to the associated item type (words in brackets are optional additions):
		(main-)section = section heading
		(basic-)function = function description
		library(-section/function) = standard library
		api(-section/function) = application inferface
	A single argument section number given as a string (eg '2.3.4') shows that section (without subsections).
	Any word that is the empty string '' or fullstop '.' is ignored.]],
	makehelp_usage = [[lua help.lua <path to the lua html manual file>
	Uses the given file to produce a help-table module needed by the help function.
	The created module filename contains the running lua version number and language,
	and is put in the same directory as the given file, any existing file is overwritten.
	The language is automatically discovered from the manual file.
	Supported languages are: %s]],
 	console_usage = [["help make <manualfile>" or "help <words>"
	Create a new lua help script using the given manual file, or search the lua manual for the given words.
	]];
	
	main = 'main', api = 'api', lib = 'lib', basic = 'basic';
	
	notfound = 'Manual module %s not found',
	nomanual = 'No manual modules found',
	langnot = 'Language not supported',
	restrict = 'Restricting search to section type: %s',
	nothing = 'The search found nothing.', 
	loaded = 'Loaded manual version: %s',
	overwrit = 'Overwriting existing target file "%s".',
	found = 'Found %i match%s in %i section%s.',
	versions1 = 'Running Lua version: %s\nDefault manual version: %s',
	versions2 = 'Other loaded versions: %s',
	altversion = 'Alternative version: %s',
	noaltversion = 'There is no alternative version',
	versionformat = 'Wrong version format in config file; must be 2 digits followed by 2 letters, eg 51en.',
	nodefault = 'Default manual version "%s" not found.',
	prompt = '%s help: ',
 	noresult = 'There is no such result.',	
}
function S.format(t, name, ...) 
	return (...) and t[name]:format(...) or t[name]
end
local function Q(s, ...) print(S:format(s, ...)) end
local function E(errorcondition, s, ...) 
	if errorcondition then error(S:format(s, ...)) end
end

local L = { 'en', en = 1; 'es', es = 2; 'pt', pt = 3;
	manualtitle = { 'reference', 'referencia', 'refer&ecirc;ncia' },
	apisection = { 'application', 'aplicación', },
	api2section = { 'auxiliary%s+libr', },
	libsection = { 'standard%s+libr', },
 	basicsection = { 'basic%s+func', },

	which = function(self, text, name) for i, w in ipairs(self[name]) do if text:lower():match(w) then return i end end end
}

local headpattern = '<h%d>(.-)</h%d>'

delim = { sentence = '\1', listitem = '\2', preformat = '\3', paragraph = '\4'; 
	oneof = '[\1\2\3\4]', noneof = '[^\1\2\3\4]', formatting = '[\2\3\4]' }

local charset = {
-- Mapping manual source character set to utf8
-- Use HTML entity names
	utf8 = {
		ecirc = '\xc3\xaa',
		ntilde = '\xc3\xb1',
		sect = '\xc2\xa7',
		acute = '\xc2\xb4',
		lsquo = '\xe2\x80\x98',
		rsquo = '\xe2\x80\x99',
	},
	
	iso88591 = {	
		ecirc = '\xea',
		ntilde = '\xf1',
	},
}

local textmap = {
-- Parses html into a text containing no html tags, 
-- Some tags are replaced by single character delimiters to mark sentences, list items, preformatted lines and paragraphs.
	init = function (self) for i = 1, #self, 2 do if not self[i+1] then self[i+1] = charset.utf8[self[i]:match'%a+'] end end end, -- Sets utf8 codes.
	map = function (self, s) for i = 1, #self, 2 do s = s:gsub(self[i], self[i+1]) end return s end,
	delim.oneof, '';
	'&nbsp;', ' ';
	'&middot;', '.';
	'&ndash;', '-';
	'&acute;', nil;
	'&sect;', nil;
	'&lsquo;', '`';
	'&rsquo;', nil;
	'<sup>(.-)</sup>', '^%1';
	'<pre>(.-)</pre>', function(s) return s:gsub('(.-)\n', '\3%1')..'\1' end;
	'<p>', delim.paragraph..delim.sentence;
	'([^%.]%.)\n', '%1'..delim.sentence;
	'(%.%))\n', '%1'..delim.sentence;
	'\n', ' ';
	'<li>'..delim.sentence, '<li>'; -- To remove any spurious list end markers.
	'<li>', delim.listitem; 
	'</li>%s*</ul>', delim.listitem..delim.sentence;
 	'<span .->(%[[^%]]+%])</span>', '%1'..delim.sentence;
	'(["\']?)<code>(["\']?)(.-)%2</code>%1', function(outer, inner, text) return '"'..text:gsub('"', "'")..'"' end;
	--'<a .->([^<]+)</a>', '%1';
	'<.->', ''; -- Remove any other tags before introducing the tag-brackets.
	'&lt;', '<';
	'&gt;', '>';
	'&amp;', '&';
}

local sectnum_any = '^%d?%.?%d?%.?%d?$'
local sectnum_text = '^%d%d?.%d?d?%.?%d?d?' 

local function sectnum(x)
	local function digits(x)
		if x == 0 then return {0} end
		local t = {}
		for n = math.floor(math.log10(x)), 0, -1 do
			local p = 10^n
			local d = math.floor(x/p)
			table.insert(t, d)
			x = x - d*p
		end
		return t
	end
	if x:match'^%.%d+' then
		x = tonumber(x:sub(2))
		if x and x >= 0 then 
			x = table.concat(digits(x), '.') 
			if not x:match'%.' then x = x..'.' end
			return x
		else return end
	else return x:match(sectnum_text) end
end

local sectiontitle = '(%d?%d?%.?%d?%d?%.?%d?%d?).+>%s*([^<]+)'
 
local apifunction = '^lua%a?_%w+$'
local libfunction = '^[^%.%s]+[%.:][^%.%s]+$'

local function searchpattern(s)
-- Makes a search pattern from a user given search text: includes both upper & lower case letters and optional space for hyphen.
		return (s:gsub('[%-%.%+%[%]%(%)%$%^%%%?%*]', '%%%1'): -- The following patterns must take account of the here escaped magic characters.
			gsub('%a', function(c) return '['..c:lower()..c:upper()..']' end)): -- Match both lower and upper case on each letter.
			gsub('(%a)%%%-(%a)', '%1[%%- ]%2') -- Also match space for a hyphen separating 2 words.
end

local itemtype = { 
	'main', main = 1; 'api', api = 2; 'lib', lib = 3; 'basic', basic = 4;
	sections = { apisection = 'api'; api2section = 'api'; libsection = 'lib'; basicsection = 'basic'; },
 	find = function (self, s) 
		for i, name in ipairs(self) do 
			if name:match('^'..searchpattern(s)) then return i end 
		end 
	end,
	set = function (self, item, lang)
		if item.title:match'^%d' then
			for name, typ in pairs(self.sections) do
				if item.title:lower():match(L[name][lang]) then item.typ = self[typ] break end 
			end
		end
	end
}

local function sections(s, headpattern)
	local start = 1
	local iter = function()
		if start > #s then return end
		local first, last, title, text, final = s:find(headpattern..'(.-)('..headpattern..')', start)
		if not first then
			first, last, title, text = s:find(headpattern..'(.*)', start)
			if not first then return false, s end
			if first and start == first then start = #s + 1 return title, text end -- Return last section
		end
		if start == 1 and first > start then local r = s:sub(1, first-1) return false, r end -- Return prefix
		start = last + 1 - #final
		return title, text
	end
	return iter
end

local branch = {
-- Represents a tree branch as a stack with a function to place an item thereby either growing or diminishing the branch.
-- Items may be placed at a position or, if none given, at the top position.
-- The parent of the inserted element is returned, nil at top level.
	put = function(self, x, l)
		assert(not l or l > 0 and l <= #self+1)
		if not l then self.leaf = x return self[#self]
		elseif l < #self then self:popto(l) end
		self[l] = x
		return self[#self-1]
	end,
	pop = function(self) table.remove(self) end,
	push = function(self, x) table.insert(self, x) end,
	popto = function(self, n) -- Pop all down to but excluding the given position.
		for i = n+1, #self do table.remove(self) end
	end,
}
--_G.br = branch

local function walk(t, f)
-- Walks all members of a tree table, entering any subtables and calling a function for each member.
-- The callback function receives the entered subtable, and a numeric member index.
-- The branch of parents is updated and available as an upvalue.
-- It is called on entry, exit and for each number-indexed member.
-- If the callback returns false on first entry to a subtable, any of its subtables are skipped.
	if f(t) == false then return end
	branch:push(t)
	if t[1] then
		local i = 1
		while i <= #t do
			if type(t[i]) == 'table' then walk(t[i], f) else f(t, i) end	
			i = i + 1
		end
	end
	branch:pop()
	f() -- To indicate end of table
end

local function trim(s) 
-- Trim outer space; the first part is for the space-only string.
	return s:match'^()%s*$' and '' or s:match'^%s*(.*%S)'
end 

local function manualtree(html, lang)
	local m = {}
	branch:popto(0)
	for head, text in sections(html:sub((html:find(headpattern))), headpattern) do 
	-- Cut off the initial html before the first heading.
		local t
		if #m == 0 then -- The root section.
			m.title, m.typ, t = trim(textmap:map(head)), itemtype.main, m
		else
			local chapnum, title = head:match(sectiontitle)
			title = trim(chapnum and textmap:map(title) or head)
			-- Discover the tree level of the section from the section numbering.
			local level
			if chapnum and chapnum > '' then 
				level = select(2, chapnum:gsub('%.','')) + 1
				title = chapnum..(chapnum:match'%.' and '' or '.')..' '..title
			end
			t = { title = title } 
			table.insert(branch:put(t, level) or m, t)	
			itemtype:set(t, lang)
		end
		F('title: %s', t.title)
		-- Parse the section text into sentences.
		text = textmap:map(text)
		local s = text:match('^'..delim.noneof..'*')
		if s:match'%S' then table.insert(t, trim(s)) end
		for c, s in text:gmatch('('..delim.oneof..')('..delim.noneof..'*)') do
			if s:match'%S' or c == delim.listitem or c == delim.paragraph then
				table.insert(t, c == delim.preformat and delim.preformat..s or (c == delim.sentence and '' or c)..trim(s))
			end
		end	
	end
	-- Set the section type for all sections by inheritance.
	branch:popto(0)
	walk(m, function(t, n) 
		if not t or n or t.typ then return end
		for i = #branch, 1, -1 do t.typ = branch[i].typ if t.typ then break end end
		t.typ = t.typ or m.typ
	end)
	return m
end

local function find(m, words, typ, titles)
--[[Finds the given words of the given item-type in the help table and returns a list of section match tables.
	Each such table contains: the section table reference followed by indexes of any matching sentences, 
	plus named indexes for the total number of matches and the given words.
	Words and item-type may be nil/empty to omit the respective filtering, and search may be restricted to titles only.
	Returns nil if there are no matches.]]
	local results, search, lastitem = {}
	results.n, results.words, results.manual = 0, words, m
	if words then
		search={}
		for i=1,#words do
			search[i] = searchpattern(words[i])
		end
	end
	walk(m, 
		function (t, n)
			if not t or (n and titles) or (typ and typ ~= t.typ) then return end
			if words then
				local i = 1
				while i <= #words and (n and t[n] or t.title):match(search[i]) do i = i + 1 end
				if i <= #words then return end
			end	
			results.n = results.n + 1
			if not n or t ~= lastitem then
				lastitem = t
				table.insert(results, {section = t; t and n})
			else table.insert(results[#results], n) end 
		end
	)
	return results[1] and results
end

local console = { 
	code = {
		reset = 0; 
		bold = 1;
		red = 31, green = 32, brown = 33, blue = 34, cyan = 36; 
		lineup = '\27[1A', eraseline = '\27[2K'; },
	style = function (self, name)
		seq = '\27[%im'
		return function(s) return seq:format(self.code[name])..s..seq:format(self.code.reset) end
	end,
	vislen = function (self, s) -- Finds the (shorter) visual length of the given string which possibly contains format strings.
		local n = 0
		s:gsub('\27%[%d+m', function (m) n = n + #m end)
		return #s - n
	end
}
 
local wordhighlight = C.useconsole and console:style(C.console.word)'%0' or C.highlight..'%0'..C.highlight
local function highlight(s, words)
-- Highlight a set of words (in a table) in a given string.
	if words[1] then for _, w in ipairs(words) do s = s:gsub(searchpattern(w), wordhighlight) end end
	return s
end

local pager

local function show_section(section, words, which)
	local lastdelim
	local function showline (l)
		local listitem, s
		if l[1] == delim.paragraph or l[1] == delim.listitem then s = table.concat(l, ' ', 2)
		elseif l[1]:match('^'..delim.formatting) then listitem, s = l[1]:match('^'..delim.listitem), table.concat(l, ' '):sub(2)
		else s = table.concat(l, ' ') end
		s = words and highlight(s, words) or s
		if listitem then pager(s, C.indent + #C.listbullet + 1, string.rep(' ', C.indent)..C.listbullet..' ')
		else
			if C.pgspace and (l[1] == delim.paragraph or l[1]:match('^'..delim.preformat) and lastdelim ~= delim.preformat) then pager'' end 
			pager(s, C.indent)
		end
		lastdelim = l[1]:sub(1,1)
	end
	local i, line, skipsign, skipped, c = 1, {}, '...'
	while type(section[i]) == 'string' do
		local sentence = section[i]
	 	c = sentence:match('^'..delim.formatting)
		if c and #line > 0 then showline(line) line = {} end
		if which and not which[i] then
			if not skipped then skipped = true table.insert(line, skipsign) end
		else skipped = false table.insert(line, sentence) end
		i = i + 1
	end
	if #line > 0 then showline(line) end
end

local function spreadline(z, a, b)
-- Spreads 2 strings into a given size line, ie. the first left-, the second right-aligned.
-- If there is not enough space for both, the second string is dropped.
	local n = z - #a - #b
	return n > 0 and a..string.rep(' ', n)..b or a:sub(1, z)
end

local function show_title(manual, section, number)
-- Show a section title with optional prefixed number.
-- Attempt to show the section type right-aligned, if space permits.
	local typ = ('(%s %s)'):format(itemtype[section.typ], manual.version:sub(1,2))
	local s = spreadline(C.maxcolumn - (number and C.indent or 0), section.title, typ)
	local numstr
	if number then
		local num = C.matchnumber:format(number)
		num = num..string.rep(' ', C.indent - #num)
		numstr = C.useconsole and console:style(C.console.matchnumber)(num) or num
	end
	pager((numstr or '')..(C.useconsole and console:style(C.console.title)(s) or s))
end

local function show_titled_section(manual, section, words, deep)
	walk(section,
		function (t, n)
			if t and not n then
				pager''
				show_title(manual, t)
				show_section(t, words)
				if not deep then return false end
			end
		end
	)
end

local function show_matches(m, results)
	local function intball(c, r, f) 
	-- Find all integers contained in a ball centered at c, radius r, and call the func on for each.
		for i = math.ceil(c - r), math.floor(c + r) do f(i) end
	end 
	if not results then Q'nothing' return end
	Q('found', results.n, results.n > 1 and 'es' or '', #results, #results > 1 and 's' or '')
	for n, r in ipairs(results) do	
		local section = r.section
		pager''
		show_title(m, section, n)
		local which = {} -- The sentences to be shown.
		for i = 1, #r do intball(r[i], C.showsize/2, function (n) which[n] = true end) end
		show_section(section, results.words, which)
	end
end

local function show_titles(m, results)
	if not results then Q'nothing' return end
	for n, r in ipairs(results) do
		if r.section.title:match'^%d' then pager'' end
		show_title(m, r.section, n)
	end 
end

local function iconv(text, from, to)
	assert(from ~= 'utf8')
	local charname, s = {}, ''
	for name, char in pairs(charset[from]) do
		charname[char] = name
		s = s..char
	end
	return text:gsub('['..s..']', function (c) return charset[to][charname[c]] end)
end
 
local function make(manualfile)
-- Creates a manual module file form a given manual html file
	if not manualfile then Q('makehelp_usage', table.concat(L, ', ')) return end
	local f = assert(io.open(manualfile))	
	local html = f:read'*a' f:close()
	print (html)
	local vernum = html:match(headpattern):gsub('<.->', ''):match'%d%.%d':gsub('%.','')
	local language = L:which(html:match(headpattern), 'manualtitle')
	if not language then E'langnot' end
	local m = manualtree(iconv(html, 'iso88591', 'utf8'):gsub('%s*\n', '\n'), language)
	local version = vernum..L[language]
	local targetfile = C.manualmodname..version..'.lua'
	local g = io.open(targetfile) if g then Q('overwrit', targetfile) g:close() end
 	g = assert(io.open(targetfile, 'w'))
	local function writeln(s) g:write(s..'\n') end
	writeln'return '
	local function esc(s) return string.format('%q', s) end
	walk(m, function(t, n)
			if not t then writeln'},' return end
			if n then writeln(esc(t[n])..',')
			else writeln(string.format('{ title = %s, typ = %i;', esc(t.title), t.typ)) end
			return
		end
	)
	writeln'nil' -- To account for the last trailing comma.
 	g:close()
end

local function matchname(name, abbr) return name:match('^'..searchpattern(abbr)) end

local manuals, results 

local function help(words)
	-- Parses the given words, finds the matching items and displays them.
	-- Run as a coroutine, though the yield happens only 2 levels down in the pager.
	assert(words and #words > 0)
	local m = manuals[manuals[1]]
	local w1 = words[1]
	local matchnum = tonumber(w1:match'^(%d+)%*?$')
	if matchnum and #words == 1 then -- Select from last results
		if results and matchnum <= #results and matchnum >= 1 then
			show_titled_section(results.manual, results[matchnum].section, results.words) 
		else Q'noresult' end
		return
	end
	local v = w1:match'^v+$'
	if v then
		table.remove(words, 1) w1 = words[1]
		if v == 'v' and not w1 then
			Q('versions1', luaversion, manuals[1])
			if manuals[2] then Q('altversion', manuals[2]) end 
			if #manuals > 2 then Q('versions2', table.concat(manuals, ', ', 2)) end
			return
		elseif v == 'v' then if manuals[2] then m = manuals[manuals[2]] else Q'noaltversion' end
		end
	end
	if not w1 or w1 == '' then Q'help_usage' return end
	local typ = itemtype:find(w1)
	if matchname('title', w1) then
		table.remove(words, 1)
		results = find(m, words, nil, true)
		show_titles(m, results)
	elseif #words == 1 and typ then
		results = find(m, nil, typ, true)
		show_titles(m, results)
	elseif #words == 1 and w1:match'^%a+[%._:]$' then
		results = find(m, words, nil, true)
		show_titles(m, results)
	else
		local typ, section, sectnum = itemtype:find(w1), matchname('section', w1), sectnum(w1)
		if typ or section then
			table.remove(words, 1) if #words == 0 then Q'help_usage' return end
			if typ then Q('restrict', itemtype[typ]) end
		elseif sectnum then
  			local section
            walk(m, function(t, n) if t and not n and t.title:match('^'..sectnum) then section = section or t end end)
            if section then show_titled_section(m, section, nil, true) else Q'nothing' end
            return
		end
		if typ or section or w1:match(apifunction) or w1:match(libfunction) then 
			for _, titles in ipairs{true, false} do
				results = find(m, words, typ, titles)
		 		if results then show_titled_section(m, results[1].section, words) return end
			end
			Q'nothing'
			return
		end
		results = find(m, words, typ)
		show_matches(m, results)
	end
end

local function wraplines(s, z)
-- Iterator splitting a given single text line into equally sized pieces of given size.
-- Returns an additional true value on the first piece.
-- A line with initial space is taken as preformatted and simply curtailed.
-- If size is nil, the iterator returns the line unchanged.
	assert(not s:match'\n')
	local breaks  = '%s%-,%.;:%]}%)!%?'
	local initial, final, last = true, false
	return function()
		if final then return end
		if not z then final = true return s, true end
		if not s:match'%S' or s:match'^%s' then final = true return s:sub(1, z), true end
		local l = C.useconsole and console:vislen(s) or #s
		if l > z then
			if s:sub(z,z):match('['..breaks..']') or s:sub(z+1,z+1):match'%s' then last = z
			else
				last = s:sub(1, z):find('['..breaks..'][^'..breaks..']+$')
				if last and last < z/2 then last = nil end -- Favors the hyphen word break if resulting line is too short.
			end
			local p = last and s:sub(1, last) or s:sub(1, z-1)..'-' 
			s = s:sub(last and last+1 or z):match'^%s*(.*)'
			if initial then initial = nil return p, true else return p end
		else final = true return s:match'^%s*(.*)'end
	end
end

local function empty(s) return not s:match'%S' end

local iomode

local function newpager()
	-- Produces a pager function as an upvalue for the show-functions.
	local lines, lastempty = 0 
	local pagescroll = C.useconsole and C.console.pagescroll or C.pagescroll
	pager = function (line, indent, prefix)
		if empty(line) then 
			if not lastempty then P'' lines, lastempty = lines + 1, true end				
			return
		end lastempty = false
		local indent = indent and string.rep(' ', indent) or ''
		for l, init in wraplines(line, C.maxcolumn and (C.maxcolumn - #indent)) do
			print ((init and prefix or indent)..l)
			lines = lines + 1
			if iomode:match'i' and (lines == C.initialpage or 
				lines > C.initialpage and (lines - C.initialpage) % pagescroll == 0)
				then coroutine.yield()
			end
		end
	end
end

local function split(s)
	local t = {}
	for w in s:gmatch'%S+' do
		table.insert(t, w)
	end
	return t
end

local function help_command(...)
	local words, c, lastc
	iomode = C.iomode
	if select('#', ...) == 1 and type(...) == 'string' then words = split(...)
	elseif type(...) == 'table' then words = ...
	else words = {...} end
	if #words == 0 then Q'help_usage' return end
	for i, word in ipairs(words) do words[i] = tostring(word) end
	if matchname('input', words[1]) then 
		iomode = 'i'
		table.remove(words, 1)
		if #words == 0 then words[1] = '' end
	elseif matchname('output', words[1]) then 
		iomode = 'o'
		table.remove(words, 1)
		if #words == 0 then Q'help_usage' return end
	end
	helpcs = {i=0} -- Keep a list of help threads for help history.	
	while words do -- Do a new search
 		helpc = coroutine.create(help)
		table.insert(helpcs, helpc) helpcs.i = #helpcs
		newpager()
		local input, prompt
		while not input do -- Continue with the old search
			coroutine.resume(helpc, words)
			if coroutine.status(helpc) == 'dead' then
				if iomode == 'o' then return end
				prompt = S.prompt:format'-'
				if helpcs[helpcs.i] == helpc then 
					table.remove(helpcs, helpcs.i) helpcs.i = #helpcs		
				end	
			else prompt = S.prompt:format'v' end
			--P('helpcs # i', #helpcs, helpcs.i) 
			if C.useconsole then io.write(console:style(C.console.wait)(prompt))
			else io.write(prompt) end
			input, words = trim(io.read()), nil
			if input == '<' or input == '>' then
				if input == '<' and helpcs.i > 1 then helpcs.i = helpcs.i - 1
				elseif input == '>' and helpcs.i < #helpcs then helpcs.i = helpcs.i + 1 end
				helpc, input, words = helpcs[helpcs.i], '', input
			end
			if empty(input) then input = nil end
			if input and not matchname(C.exitword, input) then
				words = split(input)
			end
			if C.useconsole and not (input and words) then 
				io.write(console.code.lineup..console.code.eraseline)
			end -- Remove prompt line when continuing previous output or ending.
		end
	end
end

local function loadmanuals()
-- Load any manuals found and list their version names.
	local manuals, default = { false }, luaversion..C.language
	for version in C.versions:gmatch'%S+' do
		E(not version:match'^%d%d%l%l$', 'versionformat')
		local done, m = pcall(require, C.manualmodname..version)
		E(not done, 'notfound', C.manualmodname..version)
		m.version = version
		manuals[version] = m
		if version == default then manuals[1] = default else table.insert(manuals, version) end
	end
	E(manuals[1] ~= default, 'nodefault', default)
	return manuals
end

local function main(...)
	local function merge(a, b) for k, v in pairs(b) do a[k] = v end end
	local done, m = pcall(require, C.configmodname)
	if done then merge(C, m) end
	textmap:init()
	if ... == 'help' then -- Loaded as library module
		manuals = loadmanuals()	
		return help_command
	else -- Interactive command
		if select('#', ...) == 0 then Q'console_usage' return end
		if select(1, ...) == 'make' then make(select(2, ...))
		else
	  		manuals = loadmanuals()
			help_command(...)
		end
	end
end

return main(...)

