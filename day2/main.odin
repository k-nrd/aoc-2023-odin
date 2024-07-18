package main

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:testing"

Rgb :: struct {
	red:   int,
	green: int,
	blue:  int,
}

Game :: struct {
	id:      int,
	samples: [dynamic]Rgb,
}

process_line :: proc(game: ^Game, line: string) {
	game_id_section, _, game_info_section := strings.partition(line, ":")
	_, _, game_id_str := strings.partition(game_id_section, " ")
	game_samples, _ := strings.split_multi(game_info_section, []string{";", ","})
	defer delete(game_samples)

	game.id = strconv.atoi(game_id_str)

	sample_info := Rgb{}

	for sample in game_samples {
		trimmed_sample := strings.trim_space(sample)
		quantity, _, _ := strings.partition(trimmed_sample, " ")
		if strings.contains(trimmed_sample, "red") {
			sample_info.red += strconv.atoi(quantity)
		} else if strings.contains(trimmed_sample, "green") {
			sample_info.green += strconv.atoi(quantity)
		} else if strings.contains(trimmed_sample, "blue") {
			sample_info.blue += strconv.atoi(quantity)
		}
		append(&game.samples, sample_info)
		reset_sample(&sample_info)
	}
}

possible_sample :: proc(sample: ^Rgb, params: ^Rgb) -> bool {
	return sample.red <= params.red && sample.green <= params.green && sample.blue <= params.blue
}

possible_game :: proc(game: ^Game, params: ^Rgb) -> bool {
	for &sample in game.samples {
		if !possible_sample(&sample, params) do return false
	}
	return true
}

reset_sample :: proc(sample: ^Rgb) {
	sample.red = 0
	sample.green = 0
	sample.blue = 0
}

reset_game :: proc(game: ^Game) {
	game.id = 0
	clear(&game.samples)
}

delete_game :: proc(game: ^Game) {
	delete(game.samples)
}

decode :: proc(filepath: string, params: ^Rgb) -> (sum: int) {
	data, ok := os.read_entire_file(filepath)
	if !ok do return
	defer delete(data)

	it := string(data)

	game := Game{}
	defer delete_game(&game)

	for line in strings.split_lines_iterator(&it) {
		process_line(&game, line)
		if possible_game(&game, params) {
			sum += game.id
		}
		reset_game(&game)
	}

	return
}

main :: proc() {
	sum := decode("./day2/input.txt", &Rgb{red = 12, green = 13, blue = 14})
	fmt.printfln("Result: %i", sum)
}

@(test)
test_example :: proc(t: ^testing.T) {
	sum := decode("./day2/example-game.txt", &Rgb{red = 12, green = 13, blue = 14})
	expected := 8

	testing.expectf(t, sum == expected, "Expected %i, got %i", expected, sum)
}
