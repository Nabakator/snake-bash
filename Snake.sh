#!/usr/bin/env bash
# Terminal Snake. Compatible with bash 3.2+ (the macOS default).

N=20
M=40
SNAKE_HEAD='@'
SNAKE_BODY='O'
FOOD='*'
EMPTY=' '
BORDER='#'
# 1-D indexed array (cell = x*M + y): associative arrays need bash 4.
grid=()
snake_x=()
snake_y=()
snake_length=5
snake_dir='d'
score=0
food_x=0
food_y=0
game_over=false
saved_stty=''

initialize_game() {
    grid=()
    snake_x=()
    snake_y=()

    # Initialize the grid
    for (( i=0; i<N*M; i++ )); do
        grid[i]=$EMPTY
    done

    # Initialize the snake
    local head_x=10
    local head_y=20
    for (( i=0; i<snake_length; i++ )); do
        snake_x[i]=$head_x
        snake_y[i]=$((head_y-i))
        grid[head_x*M+head_y-i]=$SNAKE_BODY
    done
    grid[head_x*M+head_y]=$SNAKE_HEAD

    place_food
}

place_food() {
    # Give up if the board is full (the snake fills every cell).
    (( snake_length >= N*M )) && return
    food_x=$((RANDOM % N))
    food_y=$((RANDOM % M))
    while [ "${grid[food_x*M+food_y]}" != "$EMPTY" ]; do
        food_x=$((RANDOM % N))
        food_y=$((RANDOM % M))
    done
    grid[food_x*M+food_y]=$FOOD
}

print_grid() {
    # Build the whole frame first, then draw it in one write to avoid flicker.
    local border_row frame='' row
    printf -v border_row '%*s' $((M+2)) ''
    border_row=${border_row// /$BORDER}

    frame+="$border_row"$'\n'
    for (( i=0; i<N; i++ )); do
        row=$BORDER
        for (( j=0; j<M; j++ )); do
            row+="${grid[i*M+j]}"
        done
        frame+="$row$BORDER"$'\n'
    done
    frame+="$border_row"$'\n'
    frame+="Score: $score"

    clear
    printf '%s\n' "$frame"
}

move_snake() {
    local new_x=${snake_x[0]}
    local new_y=${snake_y[0]}

    case $snake_dir in
        d) ((new_y++)) ;;
        q) ((new_y--)) ;;
        z) ((new_x--)) ;;
        s) ((new_x++)) ;;
    esac

    # Hitting a wall ends the game
    if (( new_x < 0 || new_x >= N || new_y < 0 || new_y >= M )); then
        game_over=true
        return
    fi

    local target=${grid[new_x*M+new_y]}
    local tail_index=$((snake_length-1))
    local tail_x=${snake_x[tail_index]}
    local tail_y=${snake_y[tail_index]}

    # Hitting the body is fatal, except the tail cell, which moves away
    # this same tick (unless we are eating, in which case we never get here
    # because the target is food, not body).
    if [ "$target" == "$SNAKE_BODY" ] && ! (( new_x == tail_x && new_y == tail_y )); then
        game_over=true
        return
    fi

    if [ "$target" == "$FOOD" ]; then
        ((score+=10))
        ((snake_length++))
    else
        # Remove the tail
        grid[tail_x*M+tail_y]=$EMPTY
        snake_x=("${snake_x[@]:0:tail_index}")
        snake_y=("${snake_y[@]:0:tail_index}")
    fi

    # Move snake's head
    grid[snake_x[0]*M+snake_y[0]]=$SNAKE_BODY
    grid[new_x*M+new_y]=$SNAKE_HEAD
    snake_x=("$new_x" "${snake_x[@]}")
    snake_y=("$new_y" "${snake_y[@]}")

    # Place food only after the head occupies its cell, so it can't spawn there.
    [ "$target" == "$FOOD" ] && place_food
}

read_key() {
    # Reads one byte honoring the current stty min/time settings.
    # (bash's own `read -n1` overrides those, and `read -t 0.1` needs bash 4.)
    dd bs=1 count=1 2>/dev/null
}

read_input() {
    local key new_dir
    key=$(read_key)
    case $key in
        d|D) new_dir=d ;;
        q|Q) new_dir=q ;;
        z|Z) new_dir=z ;;
        s|S) new_dir=s ;;
        *) return ;;
    esac
    # Ignore an instant 180° turn, which would run straight into the neck.
    case $snake_dir$new_dir in
        dq|qd|zs|sz) return ;;
    esac
    snake_dir=$new_dir
}

restore_terminal() {
    [ -n "$saved_stty" ] && stty "$saved_stty"
    printf '\e[?25h'   # show cursor
}

# game-end
handle_game_over() {
    # Block until a key is pressed.
    stty min 1 time 0
    while true; do
        echo "Game Over LOSER! Final Score: $score"
        echo "Press 'Enter' to play again or 'Esc' to exit."
        local input
        input=$(read_key)
        if [[ $input == "" || $input == $'\n' || $input == $'\r' ]]; then
            game_over=false
            score=0
            snake_length=5
            snake_dir='d'
            initialize_game
            break
        elif [[ $input == $'\e' ]]; then
            exit 0
        fi
    done
    # Back to non-blocking reads with a 0.1s timeout.
    stty min 0 time 1
}

main() {
    saved_stty=$(stty -g)
    trap restore_terminal EXIT
    trap 'exit 130' INT TERM
    stty -echo -icanon min 0 time 1
    printf '\e[?25l'   # hide cursor

    initialize_game
    while true; do
        while ! $game_over; do
            read_input
            move_snake
            print_grid
            sleep 0.3
        done
        handle_game_over
    done
}

# Allow sourcing the functions (e.g. for tests) without starting the game.
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    main
fi
