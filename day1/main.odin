package main

import "core:fmt"
import "core:io"
import "core:os"
import "core:strings"
import "core:testing"

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

consume_line :: proc(stream: ^io.Stream, buffer: ^[dynamic]rune) -> (bool, io.Error) {
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
	for i, j := index, 0; i <= bounds; i, j = i + 1, j + 1 {
		if line[i] != cast(rune)word[j] do return false
	}
	return true
}

process_line :: proc(line: ^[dynamic]rune) -> int {
	low, high, high_index := 0, 0, 0
	for i := 0; i < len(line); i += 1 {
		ch := line[i]

		if ch == '\n' do break

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
			value = digits[ch]
		}
		if value == 0 do continue

		if low == 0 {
			low = value
			// log.infof("New low: %i", low)
		} else if high == 0 || i > high_index {
			high = value
			high_index = i
			// log.infof("New high: %i, index: %i", high, high_index)
		}
	}
	return (low * 10) + (high_index == 0 ? low : high)
}

decode :: proc(stream: ^io.Stream) -> (sum: int, err: io.Error) {
	line_buffer := make([dynamic]rune)
	defer delete(line_buffer)
	for eof := false; !eof; {
		eof = consume_line(stream, &line_buffer) or_return
		value := process_line(&line_buffer)
		sum += value
		// log.infof("Computed value %i", value)
	}
	return sum, nil
}

main :: proc() {
	f, err := os.open("./day1/input.txt")
	if err != os.ERROR_NONE {
		fmt.eprintfln("ERROR: %i", err)
		return
	}
	defer os.close(f)

	stream := os.stream_from_handle(f)
	defer io.destroy(stream)

	result, _ := decode(&stream)
	fmt.printfln("Result: %i", result)
}

@(test)
test_example :: proc(t: ^testing.T) {
	sample_input := "1abc2\npqr3stu8vwx\na1b2c3d4e5f\ntreb7uchet"

	reader := strings.Reader{}
	strings.reader_init(&reader, sample_input)

	stream := strings.reader_to_stream(&reader)
	defer io.destroy(stream)

	result, ok := decode(&stream)

	testing.expectf(t, ok == nil, "Expected decode to not break %i", ok)
	testing.expectf(t, result == 142, "Expected 142, got %i", result)
}

@(test)
test_example_2 :: proc(t: ^testing.T) {
	sample_input := "two1nine\neightwothree\nabcone2threexyz\nxtwone3four\n4nineeightseven2\nzoneight234\n7pqrstsixteen"

	reader := strings.Reader{}
	strings.reader_init(&reader, sample_input)

	stream := strings.reader_to_stream(&reader)
	defer io.destroy(stream)

	result, ok := decode(&stream)

	testing.expectf(t, ok == nil, "Expected decode to not break %i", ok)
	testing.expectf(t, result == 281, "Expected 281, got %i", result)
}
