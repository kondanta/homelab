use std::process::Command;

fn main() {

    // Create a command to execute shutdown command
    let command = Command::new("shutdown")
        .arg("/s")
        .arg("/t")
        .arg("0")
        .output();

    match command {
        Ok(_) => println!("Shutdown initiated"),
        Err(e) => println!("Error initiating shutdown: {:?}", e),
    }
}