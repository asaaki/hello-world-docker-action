use chrono::{DateTime, Utc};
use std::env;

fn main() {
    for (idx, arg) in env::args().enumerate() {
        println!("arg[{}] = {}", idx, arg);
    }
    for (key, value) in env::vars() {
        println!("env[{}] = {}", key, value);
    }

    let args: Vec<String> = env::args().collect();

    let name = args.get(1).cloned().unwrap_or_else(|| "World".to_string());

    let now: DateTime<Utc> = Utc::now();

    println!("Hello, {}!", name);
    println!("::set-output name=time::{}", now.to_rfc3339());
}
