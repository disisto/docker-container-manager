#!/bin/bash

#**
#    docker exec Shortcut
#    Version 0.0.1
#
#    Make quick adjustments via Docker exec without having to type the entire
#    "docker exec -it CONTAINERNAME /bin/bash" command into the CLI when needed.
#
#    Documentation: https://github.com/disisto/docker-exec-shortcut
#
#
#    Licensed under MIT (https://github.com/disisto/docker-exec-shortcut/blob/main/LICENSE)
#
#    Copyright (c) 2023 Roberto Di Sisto
#
#    Permission is hereby granted, free of charge, to any person obtaining a copy
#    of this software and associated documentation files (the "Software"), to deal
#    in the Software without restriction, including without limitation the rights
#    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#    copies of the Software, and to permit persons to whom the Software is
#    furnished to do so, subject to the following conditions:
#
#    The above copyright notice and this permission notice shall be included in all
#    copies or substantial portions of the Software.
#
#    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#    SOFTWARE.
##/

# Create a list of running Docker containers
docker_ps_output=$(docker ps --format "{{.Names}}")

# Check if a container name was provided as an argument
if [ $# -eq 1 ]; then
    selected_container="$1"
    if echo "$docker_ps_output" | grep -wq "$selected_container"; then
        echo "Selected container: $selected_container"
        docker exec -it "$selected_container" /bin/bash
    else
        echo "The specified container '$selected_container' is not in the list of running containers."
    fi
else
    # Enumerate the containers in the list
    container_list=($docker_ps_output)
    num=1
    for container_name in "${container_list[@]}"; do
        echo "$num. $container_name"
        num=$((num+1))
    done

    # Read the selected number from user input
    read -p "Choose a number to execute the corresponding container: " choice

    # Ensure the choice is a valid number
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -gt 0 ] && [ "$choice" -le ${#container_list[@]} ]; then
        selected_container="${container_list[$((choice-1))]}"
        echo "Selected container: $selected_container"
        docker exec -it "$selected_container" /bin/bash
    else
        echo "Invalid choice."
    fi
fi