# docker exec Shortcut

Make quick adjustments via Docker exec without having to type the entire ``docker exec -it CONTAINERNAME /bin/bash`` command into the CLI when needed.

### Option 1: Get list<br>
List all running containers and let select one of them. In this example ```12``` for Docker container named  ```cdn```.<br>
```./docker-selector.sh```
<br><br>
<img src="https://raw.githubusercontent.com/disisto/docker-exec-shortcut/main/img/docker-selektor.png">

### Option 2: Direct call<br>
Direct selection with the specification of the desired container. In this example ```cdn``` for Docker container named  ```cdn```.<br>
```./docker-selector.sh cdn```
<br><br>
<img src="https://raw.githubusercontent.com/disisto/docker-exec-shortcut/main/img/docker-selektor-direct.png">

### Optional: Bash/Zsh Alias<br>
To connect to the container regardless of where you are in the CLI, you can also create an alias.

1. Open your shell configuration file. Depending on the shell you're using, this might be ```~/.bashrc```, ```~/.bash_profile```, ```~/.zshrc```, or similar.<br>

2. Add the following line to the end of the file to create an alias for the ```dcon``` command:

```alias dcon="/path/to/script/docker-selector.sh"```

Replace ```dcon``` ("docker connect") with a command of your choice (e.g. ```dexec``` ("docker exec") or whatever you like).<br>
Replace ```/path/to/script``` with the actual path to your script.

3. Save the file and run the source command to load the updated alias settings into your current shell session:

```source ~/.bashrc   # or ~/.bash_profile, ~/.zshrc, depending on the file you edited```

4. Now, you can run the ```dcon``` command from anywhere to execute your script. For example:

```dcon cdn```
<br><br>

### Example for Debian 12 (Bookwork)<br>

```sudo apt install curl nano```

```sudo curl -JLO https://raw.githubusercontent.com/disisto/docker-exec-shortcut/refs/heads/main/docker-selector.sh```

  ```sudo chmod a+x docker-selector.sh```

```sudo mv docker-selector.sh .docker-selector.sh```

```sudo nano .bashrc```

Add the line ```alias dcon="/home/${USER}/.docker-selector.sh"``` at the end of the file and save with the key combination "CTRL" + "X", "Y".

```source ~/.bashrc```

```dcon```
