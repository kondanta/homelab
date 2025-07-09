use color_eyre::eyre::{Result, eyre};
use std::process::Command;

// Executes a shell command with the given arguments and returns the output as a String.
pub fn exec(cmd: &str, args: &[&str]) -> Result<String> {
    const INVALID_CMDS: [&str; 16] = [
        "rm", "mv", "cp", "echo", "cat", "ls", "pwd", "chmod", "chown", "kill", "ps", "top", "df",
        "du", "find", "grep",
    ];

    // Check if the command is in the list of invalid commands
    if INVALID_CMDS.contains(&cmd) {
        return Err(eyre!(
            "The command '{}' is not allowed to be executed.",
            cmd
        ));
    }

    let output = Command::new(cmd)
        .args(args)
        .output()
        .map_err(|e| eyre!("Failed to execute command '{}': {}", cmd, e))?;

    if !output.status.success() {
        return Err(eyre!(
            "Command '{}' failed with status {}: {}",
            cmd,
            output.status,
            String::from_utf8_lossy(&output.stderr)
        ));
    }

    Ok(String::from_utf8_lossy(&output.stdout).to_string())
}
