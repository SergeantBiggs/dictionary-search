#!/bin/bash

BASE_URL="https://www.duden.de"
SEARCH="${BASE_URL}/suchen/dudenonline"

function error_exit() {
    STATUS="$1"
    echo "$STATUS"
    echo "Error, exiting."
    exit 1
}

function usage() {
    echo "Usage: duden {word}"
}

function get_page() {
    URL="$1"


    RESULT=$(curl --silent "$URL")

    # Get name + article

    name_article=$(pup 'div.lemma text{}' <<< "$RESULT")
    name_article=$(sed '/^ *$/d;s/­//g' <<< "$name_article")

    name=$(echo "$name_article" | head -n 1)
    article=$(echo "$name_article" | tail -n 1)

    # '+' is the adjacent sibling combinator:
    # https://developer.mozilla.org/en-US/docs/Web/CSS/Adjacent_sibling_combinator
    kind=$(pup 'dt.tuple__key:contains("Wortart:") + dd text{}' <<< "$RESULT")

    # Get frequency bar
    frequency=$(pup 'dt.tuple__key:contains("Häufigkeit") + dd' <<< "$RESULT")

    bar_full=$(pup 'span.shaft__full text{}' <<< "$frequency")
    bar_empty=$(pup 'span.shaft__empty text{}' <<< "$frequency")
    bar_full=$(sed '/^$/d;s/ //g;s/▒/#/g' <<< "$bar_full")
    bar_empty=$(sed '/^$/d;s/ //g;s/░/_/g' <<< "$bar_empty")

    bar="${bar_full}${bar_empty}"

    breaks=$(pup 'dt.tuple__key:contains("Worttrennung") + dd text{}' <<< "$RESULT")
    breaks=${breaks//|/-}

    description=$(pup 'div#bedeutung p text{}' <<< "$RESULT")

    function show_result() {
        printf '%s, %s\t%s\n%s\n'       "$name" \
            "$article" \
            "$breaks" \
            "$kind"

        printf 'Beschreibung: %s\nHäufigkeit: ' "$description"

        # Fancy bar
        length=${#bar}

        for (( i=0; i<length; i++ )); do
            sleep '0.1s'
            printf '%s' "${bar:$i:1}"
            sleep '0.1s'
        done

        printf '\n'


    }

    show_result

    # Output
    while true; do
        printf '\nEntry: %s\n[p]rint, [q]uit, [c]opy\n> ' "$name"
        read -r choice

        case $choice in
            q)
                return 0
                ;;
            p)
                show_result
                ;;
            c)
                wl-copy "$name"
                echo "Copied word into clipboard"
                ;;
            *)
                echo "Option does not exist"
                ;;
        esac

    done
}

if [[ -z "$1" ]]; then
    error_exit "Please enter a word"
else
    WORD="$1"
fi

RESULTS=$(curl -L "${SEARCH}/${WORD}" 2> /dev/null | pup 'section.vignette')

END=$(echo "$RESULTS" | grep -c '</section>')

# Get all results

for ((i=1;i<=END;i++)); do
    ARGS="section.vignette:nth-of-type($i)"

    # Get elements
    LINK=$(pup "${ARGS} a.vignette__link attr{href}" <<< "$RESULTS")
    LABEL=$(pup "${ARGS} a.vignette__label text{}" <<< "$RESULTS")
    SNIPPET=$(pup "${ARGS} p.vignette__snippet text{}" <<< "$RESULTS")
    CLEAN_SNIPPET=$(sed '/^$/d;s/^ *//' <<< "$SNIPPET")

    # Again, not a normal dash ('–')
    TYPE=$(awk -F '–' '{print $1}' <<< "$CLEAN_SNIPPET")
    DEFINITION_SHORT=$(awk -F '–' '{print $2}' <<< "$CLEAN_SNIPPET")

    # Put links in array
    links+=("${BASE_URL}${LINK}")

    # Clean up text

    # The dash in this expression is not the normal one ('­')
    # Remember to copy it if it is used elsewhere
    CLEAN_LABEL=$(sed 's/[ ­]//g;/^$/d' <<< "$LABEL")

    # Show results
    printf '[%s] %s\t\t%s\n%s\n' "$i" "$CLEAN_LABEL" "$TYPE" "$DEFINITION_SHORT"

    echo "---"
done

length=${#links[@]}

while true; do
    printf '\nOptions: Select entry [0-%s], [q]uit\n> ' "$length"
    read -r choice

    [[ "$choice" == "q" ]] && exit 0

    if (( choice > 0 && choice <= length )); then
        pos=$((choice - 1))
        get_page "${links[$pos]}"
    else
        echo "Invalid number"
    fi
done

