#!/usr/bin/env ruby
%w(io/console timeout).each { |g| require(g) }

STDOUT.sync = STDIN.sync = true
VERSION = '3.0 (2019-05-08)'
PATH = File.dirname(__FILE__)

class String
	@@colours = [(34..39), (208..213), (70..75), (136..140), (214..219), (40..45),
		[154, 184, 208, 203, 198, 164, 129, 92], [63, 33, 39, 44, 49, 83, 118],
		[40,41,42,43,211, 210, 209, 208]].map(&:to_a)
	@@colours.concat(@@colours.map(&:reverse))

	def colourize(colour = @@colours.sample)
		final_string = ''
		colour = colour.to_a if colour.is_a?(Range)

		index, colour_size = 0, colour.size
		div = length / colour_size
		div = 1 if div == 0

		 each_char.with_index do |c, i|
			index += 1 if  (i % div == 0 && index < colour_size) && i > 1
			final_string.concat("\e[38;5;#{colour[index]}m#{c}")
		end

		final_string + "\e[0m"
	end

	def find_index(character) chars.map.with_index { |x, i| i if x == character }.compact end
end

unless STDIN.tty? && STDOUT.tty?
	puts 'No Terminal Found.'.colourize
	puts "Please Run #{File.basename(__FILE__)} in a Terminal.".colourize
	exit! 0
end


DANCE = <<~'EOF'.split("<...>")

		               |  O  |
		                \ + /
		                  |
		                 / \
		                 | |
				<...>
		              __  O   __
		                \ + /
			          /
		               __/ \
		                   |
				<...>
		             |  O  |
		              \ + /
		                -
		               / \__
		               |
				<...>
		             |  O  |
		              \ + /
		                \
		               / \
		               | |
EOF

def show_version
	message = "T-Hangman #{VERSION}"
	print ' ' * (STDOUT.winsize[1] / 2 - message.length / 2) + message.colourize([92, 129, 164, 198, 203, 208, 184, 154]) + "\n"
	dance = DANCE.sample.rstrip + "\n"
	dance_length = dance.each_line.map(&:length).max / 2
	print dance.each_line.map { |el| ' ' * (STDOUT.winsize[1] / 2 - dance_length) + el }[1..-1].join.colourize((70..75).to_a)
end

if ARGV.include?('--version') || ARGV.include?('-v')
	show_version
	exit

elsif ARGV.include?('--help') || ARGV.include?('-h')
	show_version

	puts <<~'EOF'.colourize
		T-Hangman is a terminal based hangman game!
		You have to guess the words. You can take help, reveal words, and enjoy!

		Arguments:
			T-Hangman takes two arguments:
				--help or -h		This help screen.
				--version or -v		Shows the version information.
	EOF
	exit

elsif ARGV.any?
	puts <<~EOF.each_line.map(&:colourize).join
		Unknown Argument!
		Skipping Bad Argument and Entering the Game in 3 Seconds.
		Press ^C to exit.
		[Too See Available Arguments, Please run `#{__FILE__} --help']
	EOF

	counter = time = Time.new.strftime('%s').to_i
	counter_2, counter_3 = 3, 0
	chars, colour = '|/-\\', [92, 129, 164, 198, 203, 208, 184, 154]

	begin
		loop do
			time_now = Time.new.strftime('%s').to_i

			if time_now - time < 3
				if time_now - counter == 1
					counter_2 -= 1
					counter = time_now
				end

				counter_3 += 2 if counter_3 < (STDOUT.winsize[1] / counter_2 - 8).abs
				colour.rotate!

				chars.each_char do |c|
					message = '=' * counter_3
					print("[#{message.colourize(colour)}#{c.colourize(colour)}#{' ' * (STDOUT.winsize[1].to_i - message.length - 8)}]\r")
					sleep 0.0125
				end
			else
				break
			end
		end

	rescue Interrupt, SystemExit
		puts
		exit 0
	rescue Exception => e
	end
end

print "\e[?25l"
$coins, $level = 50, 1

def main(init = false)
	words = IO.readlines(File.join(PATH, 'words')).map(&:upcase).reject { |w| w =~ /[^A-Z\n]/ || w.length < 3 || w.length > 11 }.map(&:strip)
	word = words.select do |x|
		case $level
			when 1 then (3..4).cover?(x.length)
			when 2 then (3..5).cover?(x.length)
			when 3 then (4..6).cover?(x.length)
			when 4 then (4..7).cover?(x.length)
			when 5 then (4..8).cover?(x.length)
			when 6 then (5..8).cover?(x.length)
			when 7 then (5..9).cover?(x.length)
			when 8 then (5..10).cover?(x.length)
			else (6..11).cover?(x.length)
		end
	end.sample

	wish, wish_colour = 'Good luck, Press Any Key to begin!', [63, 33, 39, 44, 49, 83, 118]
	message, message_colour = 'Game autostarts in ', wish_colour.dup.reverse
	autostart_timer = Time.new.strftime('%s').to_i

	loop do
		print "\e[2J\e[H\e[3J" + "\n" * (STDOUT.winsize[0] / 2 - 1)
		puts ' ' * (STDOUT.winsize[1] / 2 - wish.length / 2) + wish.colourize(wish_colour.rotate!(-1))

		begin
			Timeout.timeout(0.05) do
				throw :all_the_best! if Time.new.strftime('%s').to_i - autostart_timer > 5
				print (' ' * (STDOUT.winsize[1] / 2 - message.length.next / 2).abs + message + (5 - (Time.new.strftime('%s').to_i - autostart_timer)).to_s).colourize(message_colour.rotate!)
				STDIN.getch
				throw :good_luck!
			end
		rescue UncaughtThrowError
			break
		rescue Exception
		end
	end if init

	question = word.dup
	word.length./(2).times { question[rand(0...word.length)] = '_' }

	typed_word = ''
	wrong_count, remaining_lives = '', "\xe2\x99\xa5 " * 10
	stroke = 0
	mistaken_list = []
	menu_colour, typed_colour = (34..39).to_a, [92, 129, 164, 198, 203, 208, 184, 154]
	menu_items_colour = [63, 33, 39, 44, 49, 83, 118]
	equal_colour, lives_colour, guess_colour = typed_colour.clone, typed_colour.clone, [118, 83, 49, 44, 39, 33, 63]
	lives_colour, rem_lives_colour = typed_colour.clone, typed_colour.clone
	init_time = Time.new.strftime('%s').to_i
	clocks = Array.new(12) do |i|
		c = "\xf0\x9f\x95\x90"
		i.times { c.next! }
		c
	end.map { |x| eval "\"#{x}\"" }
	clock_tick = 0

	loop do
		clock_tick += 1
		clock_tick = 0 if clock_tick >= 12
		raw_input = ''
		mistake = false

		begin
			Timeout.timeout(0.075) do
				raw_input = STDIN.getch
				mistake = mistaken_list.include?(typed_word)
				throw :amazing!
			end
		rescue Exception
		end

		case raw_input
			when ''
			when '1' then help(word, question)
			when '2' then reveal_word(word, question)
			when '3' then main
			when '4' then change_level
			when '5' then exit_game()
			when "\u0003" then exit 0
			when "\u007F" then typed_word.clear
			when "\r" then typed_word = "\n"
			else
				if raw_input.scan(/[^a-zA-Z]/).empty?
					typed_word = raw_input.to_s.strip.upcase
					stroke += 1
				end
		end

		print "\e[3J\e[H\e[2J"

		taken_flag = false
		terminal_width = STDOUT.winsize[1]

		if word.include?(typed_word.scan(/[A-Z]/).join)
			word.find_index(typed_word).each do |w|
				if question[w] != word[w]
					question[w] = word[w]
					$coins += 1
				else
					taken_flag = true
				end
			end

		elsif !(typed_word.scan(/[^A-Z]/).any?)
			unless mistaken_list.include?(typed_word)
				wrong_count.concat("\xf0\x9f\x95\xb1 ")
				remaining_lives = "\xe2\x99\xa5 " * (10 - wrong_count.length / 2)
				$coins -= 1
				mistaken_list.push(typed_word)
			end
			lost(word) if wrong_count.length >= 20
		end unless typed_word.empty?

		col1 = ' ' * (terminal_width - "\xe2\x95\xa5 Lives: #{remaining_lives}\xe2\x9c\xaa Coins: #{$coins.to_s}".length).abs
		col2 = ' ' * (terminal_width - " \xe2\x9a\x94 Missed: #{wrong_count}\xe2\x98\x85 Level: #{$level}".length).abs

		print "\e[5m" if wrong_count.length > 10
		puts "#{"\xe2\x99\xa5 Lives:".colourize(menu_colour.rotate!(-1))} #{wrong_count.length > 10 ? "\e[5m" : ''}#{remaining_lives.colourize(lives_colour.rotate!(-1))}#{col1}#{"\xe2\x9c\xaa Coins: #{$coins}".colourize(menu_colour)}"
		puts "#{"\xe2\x9a\x94 Missed:".colourize(menu_colour)}#{wrong_count.colourize(rem_lives_colour.rotate!(1))}#{col2} #{"\xe2\x98\x85 Level: #{$level}".colourize(menu_colour)}"
		puts "#{clocks[clock_tick]} Elapsed Time: #{Time.new.strftime('%s').to_i - init_time}".colourize(menu_colour)

		puts ("\xe2\x99\xa3" * terminal_width).colourize(equal_colour)
		puts "#{' ' * (terminal_width / 2 - 2)}\e[38;5;99m\e[4mMenu\e[0m"

		puts <<~OPTIONS.colourize(menu_items_colour.rotate!(-1))
			1. Help.
			2. Reveal Word.
			3. Skip Question.
			4. Change Level.
			5. Quit.
		OPTIONS

		puts "\e[38;5;10mGuessed: \e[9m#{mistaken_list.join(' ')}\e[0m" unless mistaken_list.empty?

		print "\n" * 2
		puts "#{'Guess the word: '}#{question}".colourize(guess_colour.rotate!(-1))
		puts "Typed::#{sprintf('%03d', stroke)}#{"::#{typed_word} has been already taken" if taken_flag}#{"::Already tried #{typed_word}" if mistake}> #{typed_word}".colourize(typed_colour.rotate!(-1))

		won(word) if question == word
		game_over(word) if $coins <= 0
	end
end

def reveal_word(word, question)
	puts 'Revealing a word requires 3 coins per empty spaces.'.colourize
	puts 'Are you sure?(Y/n)'.colourize(196..201)
	inp = STDIN.gets.strip

	unless inp.upcase == 'N'
		$coins -= question.count('_') * 3
		puts ' ' * (STDOUT.winsize[1] / 2) + word.colourize([40,41,42,43,211, 210, 209, 208])
		puts "Press Enter to Continue".colourize
		STDIN.gets
		main
	end
end

def help(word, question)
	puts 'Revealing a character will cost you 3 coins.'.colourize
	indices = question.find_index('_').map(&:next).map(&:to_s)

	f = indices[0..-2]
	ad = f.any? ? ' or ' : ''

	print "Type then index (#{f.join(', ') + ad + indices[-1]}) to be revealed(q/enter/c/x to cancel)> ".colourize(196..201)

	return question if ['', 'q', 'c', 'x'].include?(inp = STDIN.gets.strip)
	int_inp = inp.to_i.-(1).abs

	if question[int_inp] == '_'
		puts "Revealed #{question[int_inp] = word[int_inp]}. Press Enter to continue.".colourize(70..75)
		$coins -= 3
	else
		puts "#{int_inp}::#{question[int_inp]} is already revealed. Nothing to do.".colourize(70..75)
	end
end

def change_level
	puts 'You can change your level anytime. This will make words harder for you!'.colourize
	print 'Type the Level (1 - 9) and Press Return/Enter Key(Return/Enter to Skip): '.colourize(196..201)

	inp = STDIN.gets.scan(/[1-9]/)[0].to_i
	return if inp == 0
	$level = inp
end

def won(word)
	message, msg, quit_msg = "Yay! You are right! The word was: #{word}", 'Press Enter/Return to Go Back and Play Again!', 'Press q to Quit'
	$coins, colour, colour2 = $coins + 5, [154, 184, 208, 203, 198, 164, 129, 92], [63, 33, 39, 44, 49, 83, 118]
	$level = $level.next if $level < 9
	msg_colour = colour.dup.reverse

	loop do
		DANCE.each do |x|
			width = STDOUT.winsize[1] / 2
			print "\e[2J\e[H\e[3J"

			puts x.each_line.map { |el| ' ' * width + el }.join.colourize(colour2.rotate!(-1))
			puts ' ' * (width - message.length / 2).abs + "#{message.colourize([154, 184, 208, 203, 198, 164, 129, 92])}\e[0m"
			puts(' ' * (width - msg.length / 2).abs + msg.colourize(colour2))
			print "\e[5m"
			puts ' ' * (width - quit_msg.length / 2).abs + quit_msg.colourize(msg_colour)

			begin
				Timeout.timeout(0.1) do
					if STDIN.getch == 'q'
						print "\e[3J\e[H\e[2J"
						print "\e[?25h"
						exit! 0
					end
					throw :awesome!
				end
			rescue UncaughtThrowError
				main
			rescue Exception
			end
		end
	end
end

def lost(word)
	$coins -= 5
	colours =  [154, 184, 208, 203, 198, 164, 129, 92]
	colours2 = [63, 33, 39, 44, 49, 83, 118]
	colours3 = (70..75).to_a

	dead = <<~EOF.strip
	You Lost :(
	_________
        |       |
        |       O
        |      \\|/
        |       |
        |      / \\
        |      | |
        |
        ===============
	EOF

	loop do
		puts "\e[3J\e[H\e[2J"

		puts dead.colourize(colours2.rotate!(-1))

		puts "The Word was: #{word}".colourize(colours2)
		puts('Press Enter/Return Key to Play Again!'.colourize(colours.rotate!))
		puts('Press q to quit'.colourize(colours2))

		begin
			Timeout.timeout(0.05) do
				input = STDIN.getch
				throw :all_the_best if input == "\r"
				exit 0 if input.strip.downcase == 'q'
			end
		rescue Timeout::Error
		rescue UncaughtThrowError
			main
		end
	end
end

def game_over(word='')
	message, message_colour = 'Game Over', [154, 184, 208, 203, 198, 164, 129, 92]

	message2, message2_colour = 'No Coins Left :(', message_colour.clone
	message3 = 'Press Return/Enter/^C to Exit'

	loop do
		print "\e[2J\e[H\e[3J" + "\n" * (STDOUT.winsize[0] / 2 - 2)
		puts ' ' * (STDOUT.winsize[1] / 2 - message.length / 2) + "\e[5m" + message.colourize(message_colour.rotate!)
		puts ' ' * (STDOUT.winsize[1] / 2 - message2.length / 2) + message2.colourize(message2_colour.rotate!(-1))
		puts ' ' * (STDOUT.winsize[1] / 2 - message3.length / 2) + message3.colourize(message_colour)

		begin
			Timeout.timeout(0.05) do
				STDIN.gets
				exit 0
			end
		rescue Interrupt, SystemExit
			puts
			exit 0
		rescue Exception
		end
	end
end

def exit_game
	print "Do you want to exit the game?(Y/n): ".colourize((22..27).to_a.reverse)
	exit 0 if STDIN.gets.strip.upcase != 'N'
end

at_exit do
	print "\e[3J\e[H\e[2J"
	print "\e[?25h"
end

begin
	main(true)
rescue Exception => e
	exit 0
end
