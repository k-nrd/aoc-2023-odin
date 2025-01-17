package main

import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:strconv"
import "core:unicode/utf8"

Mode :: enum {
	Parts,
	Gears,
}

Loc :: struct {
	index: int,
	line:  int,
	col:   int,
}

Span :: struct {
	start: Loc,
	end:   Loc,
}

TokenType :: enum {
	Number,
	Symbol,
	Invalid,
}

Token :: struct {
	using span: Span,
	token_type: TokenType,
	literal:    string,
}

Cursor :: struct {
	using loc:    Loc,
	current_rune: rune,
}

create_loc :: proc(cursor: ^Cursor) -> Loc {
	return Loc{index = cursor.index, line = cursor.line, col = cursor.col}
}

create_token :: proc(cursor: ^Cursor) -> Token {
	return Token{token_type = .Invalid, start = create_loc(cursor)}
}

create_cursor :: proc(input: ^string) -> Cursor {
	return Cursor {
		line = 1,
		col = 1,
		current_rune = len(input) == 0 ? utf8.RUNE_EOF : utf8.rune_at(input^, 0),
	}
}

advance :: proc(cursor: ^Cursor, input: ^string) {
	cursor.index += utf8.rune_size(cursor.current_rune)
	cursor.col += 1
	cursor.current_rune =
		cursor.index >= len(input) ? utf8.RUNE_EOF : utf8.rune_at(input^, cursor.index)
	if cursor.current_rune == '\n' {
		cursor.line += 1
		cursor.col = 0
	}
}

skip_while :: proc(cursor: ^Cursor, input: ^string, cond: proc(r: rune) -> bool) {
	for cursor.index < len(input) {
		if !cond(cursor.current_rune) do return
		advance(cursor, input)
	}
}

consume_token :: proc(cursor: ^Cursor, input: ^string) -> (Token, bool) {
	skip_while(cursor, input, proc(r: rune) -> bool {
		return r == '.' || r == '\n' || r == ' '
	})

	token := create_token(cursor)

	switch cursor.current_rune {
	case utf8.RUNE_EOF:
		return token, false
	case '0' ..= '9':
		token.token_type = .Number
		skip_while(cursor, input, proc(r: rune) -> bool {
			switch r {
			case '0' ..= '9':
				return true
			case:
				return false
			}
		})
		token.end = create_loc(cursor)
		token.end.col -= 1 // Cursor is already 1 column ahead of us
		token.literal = input[token.start.index:token.end.index]
	case '*', '#', '+', '$', '@', '=', '&', '%', '/', '-':
		token.token_type = .Symbol
		token.literal = utf8.runes_to_string([]rune{cursor.current_rune})
		advance(cursor, input)
	case:
		panic(fmt.tprintfln("Unexpected rune %v", cursor.current_rune))
	}

	return token, true
}

is_adjacent :: proc(tok1: ^Token, tok2: ^Token) -> bool {
	dim_ok :: proc(dim1: int, dim2: int) -> bool {
		return dim1 == dim2 || dim1 == dim2 - 1 || dim1 == dim2 + 1
	}
	// Starting or ending line is either the same or 1 above or 1 below 
	// of the other token's starting or ending line
	line_ok :=
		dim_ok(tok1.start.line, tok2.start.line) ||
		(tok1.end.line != 0 && dim_ok(tok1.end.line, tok2.start.line)) ||
		(tok2.end.line != 0 && dim_ok(tok1.start.line, tok2.end.line)) ||
		(tok1.end.line != 0 && tok2.end.line != 0 && dim_ok(tok1.end.line, tok2.end.line))
	// Starting or ending column is either the same or 1 to the left or 1 to the right
	// of the other token's starting or ending column
	col_ok :=
		dim_ok(tok1.start.col, tok2.start.col) ||
		(tok1.end.line != 0 && dim_ok(tok1.end.col, tok2.start.col)) ||
		(tok2.end.line != 0 && dim_ok(tok1.start.col, tok2.end.col)) ||
		(tok1.end.line != 0 && tok2.end.line != 0 && dim_ok(tok1.end.col, tok2.end.col))
	return line_ok && col_ok
}

collect_data :: proc(str: ^string, mode: Mode) -> (sum: int) {
	// Cursor is already primed with the first rune
	// If the length of the input is 0, then that rune will be EOF
	cursor := create_cursor(str)

	symbols := make([dynamic]Token)
	numbers := make([dynamic]Token)

	for token in consume_token(&cursor, str) {
		switch token.token_type {
		case .Symbol:
			if mode == .Parts do append(&symbols, token)
			else if mode == .Gears && token.literal == "*" do append(&symbols, token)
		case .Number:
			append(&numbers, token)
		case .Invalid:
			panic(fmt.tprintfln("Unexpected end of token stream with %v", token))
		}
	}

	for &sym in symbols {
		switch mode {
		case .Parts:
			// Part 1 
			// Check numbers in the islands array for adjacency
			// If adjacent, remove from islands
			#reverse for &num, index in numbers {
				if !is_adjacent(&sym, &num) do continue
				sum += strconv.atoi(num.literal)
				unordered_remove(&numbers, index)
			}
		case .Gears:
			num1, num2 := 0, 0
			for &num in numbers {
				if !is_adjacent(&sym, &num) do continue
				if num1 == 0 {
					// 1 adjacent
					num1 = strconv.atoi(num.literal)
				} else if num2 == 0 {
					// 2 adjacent
					num2 = strconv.atoi(num.literal)
				} else {
					// more than 2 adjacent
					num1 = 0
					num2 = 0
				}
			}
			sum += num1 * num2
		}
	}

	return
}

decode :: proc(filepath: string, mode: Mode) -> int {
	data, ok := os.read_entire_file(filepath)
	if !ok do panic(fmt.tprintfln("Could not read file %s", filepath))
	it := string(data)
	log.debugf("Schematics: \n%s", it)
	return collect_data(&it, mode)
}

// 1Mb
buf := [1 << 20]byte{}

main :: proc() {
	arena: mem.Arena
	mem.arena_init(&arena, buf[:])

	context.logger = log.create_console_logger(lowest = log.Level.Debug)
	context.allocator = mem.arena_allocator(&arena)

	result := decode("./day3/input.txt", .Gears)
	log.debugf("Result: %i", result)

	mem.free_all()
}
