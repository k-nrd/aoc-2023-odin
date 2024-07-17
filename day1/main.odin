package main

import "core:fmt"
import "core:io"
import "core:log"
import "core:slice"
import "core:strings"
import "core:testing"
import "core:unicode/utf8"

digits := map[rune]int {
	'1' = 1,
	'2' = 2,
	'3' = 3,
	'4' = 4,
	'5' = 5,
	'6' = 6,
	'7' = 7,
	'8' = 8,
	'9' = 9,
}

consume_line :: proc(stream: ^io.Stream, buffer: ^[dynamic]rune) -> (done: bool, err: io.Error) {
	clear(buffer)
	for {
		ch, _, err := io.read_rune(stream^)
		if ch == '\n' || err == io.Error.EOF {
			append(buffer, '\n')
			return err == io.Error.EOF, nil
		} else if err != nil {
			return true, err
		}
		append(buffer, ch)
	}
}

match_word_at :: proc(line: ^[dynamic]rune, word: string, index: int) -> bool {
	bounds := index + len(word) - 1
	if len(line) - 1 < bounds do return false

	i, j := index, 0
	for i <= bounds {
		if line[i] != cast(rune)word[j] do return false
		i += 1
		j += 1
	}
	return true
}

process_line :: proc(line: ^[dynamic]rune) -> int {
	last_index := len(line) - 1
	low, high := 0, 0
	high_index := 0
	for i := 0; i <= last_index; i += 1 {
		ch := line[i]
		// Hit a newline, accumulate and reset state
		if ch == '\n' do return (low * 10) + (high_index == 0 ? low : high)

		value: int
		switch ch {
		case 'o':
			if match_word_at(line, "one", i) do value = 1
		case 't':
			if match_word_at(line, "two", i) do value = 2
			else if match_word_at(line, "three", i) do value = 3
		case 'f':
			if match_word_at(line, "four", i) do value = 4
			else if match_word_at(line, "five", i) do value = 5
		case 's':
			if match_word_at(line, "six", i) do value = 6
			else if match_word_at(line, "seven", i) do value = 7
		case 'e':
			if match_word_at(line, "eight", i) do value = 8
		case 'n':
			if match_word_at(line, "nine", i) do value = 9
		case '1' ..= '9':
			log.infof("Matched digit %r", ch)
			value = digits[ch]
		}

		if value == 0 do continue

		if low == 0 {
			low = value
			log.infof("New low: %i", low)
		} else if high == 0 || i > high_index {
			high = value
			high_index = i
			log.infof("New high: %i, index: %i", high, high_index)
		}
	}
	return 0
}

decode :: proc(stream: ^io.Stream) -> (n: int, err: io.Error) {
	sum := 0
	line_buffer := make([dynamic]rune)
	defer delete(line_buffer)
	for {
		eof, err := consume_line(stream, &line_buffer)
		if err != nil {
			return sum, err
		}
		debug_line := utf8.runes_to_string(line_buffer[:len(line_buffer) - 1])
		defer delete(debug_line)
		log.infof("Consuming line %s", debug_line)
		value := process_line(&line_buffer)
		sum += value
		log.infof("Computed value %i", value)
		if eof do break
	}
	return sum, nil
}

main :: proc() {
	sample_input := "1abc2\npqr3stu8vwx\na1b2c3d4e5f\ntreb7uchet"

	reader := strings.Reader{}
	strings.reader_init(&reader, sample_input)

	stream := strings.reader_to_stream(&reader)
	result, ok := decode(&stream)

	fmt.printfln("Result %i", result)
}

@(test)
test_example :: proc(t: ^testing.T) {
	sample_input := "1abc2\npqr3stu8vwx\na1b2c3d4e5f\ntreb7uchet"

	reader := strings.Reader{}
	strings.reader_init(&reader, sample_input)

	stream := strings.reader_to_stream(&reader)
	result, ok := decode(&stream)

	testing.expectf(t, ok == nil, "Expected decode to not break %i", ok)
	testing.expectf(t, result == 142, "Expected 142, got %i", result)
}
