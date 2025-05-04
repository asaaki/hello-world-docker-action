use anyhow::{Context, Error, Result};
use chrono::{DateTime, Utc};
use envconfig::Envconfig;
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use std::{collections::BTreeMap, fs};
use structopt::StructOpt;
use url::Url;

// https://docs.github.com/en/actions/reference/environment-variables
#[derive(Debug, Envconfig)]
struct EnvConfig {
    #[allow(dead_code)]
    #[envconfig(from = "GITHUB_SERVER_URL")]
    server_url: Url,
    #[envconfig(from = "GITHUB_API_URL")]
    api_url: Url,
    #[allow(dead_code)]
    #[envconfig(from = "GITHUB_GRAPHQL_URL")]
    graphql_url: Url,
    #[envconfig(from = "GITHUB_REPOSITORY")]
    repository: String,
    #[envconfig(from = "GITHUB_EVENT_PATH")]
    event_path: String,
}

#[derive(Debug, StructOpt)]
#[structopt(about = "Example GitHub Action made with Rust and shipped as Docker image")]
struct Args {
    #[structopt(short, long, default_value = "World")]
    greetee: String,
    #[structopt(short, long)]
    token: String,
}

type MainResult = Result<()>;

// https://docs.github.com/en/developers/webhooks-and-events/webhook-events-and-payloads
// why action can be missing (also other events):
// https://docs.github.com/en/developers/webhooks-and-events/webhook-events-and-payloads#push
#[derive(Serialize, Deserialize, Debug)]
struct Event {
    action: Option<String>,
    number: Option<u64>,
    pull_request: Option<PullRequest>,
    // ...
}

// https://docs.github.com/en/developers/webhooks-and-events/webhook-events-and-payloads#pull_request

#[derive(Serialize, Deserialize, Debug)]
struct PullRequest {
    number: u64,
    // ...
}

type TypedResponse = BTreeMap<String, Value>;
// type TypedResponse = BTreeMap<Option<String>, Option<Value>>;
// type TypedResponse = Value;

#[tokio::main]
pub async fn main() -> MainResult {
    let args = Args::from_args();
    let config = EnvConfig::init_from_env()
        .with_context(|| "Could not load all required environment variables")?;

    let event_string = fs::read_to_string(config.event_path)?;
    let event: Event = serde_json::from_str(&event_string)?;

    if let Some(pr) = event.pull_request {
        let token = args.token;

        let raw_url = format!(
            "{}/repos/{}/issues/{}/comments",
            config.api_url, config.repository, pr.number
        );

        let url = Url::parse(&raw_url)?;

        println!("url = {}", &url);

        let body = json!( { "body": "Some test comment from a rusty GH action." });

        let request = reqwest::Client::new()
            .post(url)
            // ! GitHub requires an user agent string, but some client implementations do not set one by default
            .header(
                "user-agent",
                "hello-world-docker-action client (rust/stable; client=reqwest, tls=rustls)",
            )
            .header("accept", "application/vnd.github.v3+json")
            .header("authorization", format!("token {}", &token))
            .json(&body)
            ;

        let response = request.send().await.map_err(Error::msg)?;

        println!("[status] {}", response.status());
        // let headers = response.iter_mut().collect::<BTreeMap<String, String>>();
        // for (name, values) in response.iter() {
        //     println!("[headers] {:?} => {:?}", name, values);
        // }
        // println!("[response] {:#?}", res_json);

        let res_json: TypedResponse = response.json().await.map_err(Error::msg)?;

        println!("[response.id] {:#?}", res_json.get("id"));
    }

    let name = args.greetee;
    println!("Hello, {}!", name);

    let now: DateTime<Utc> = Utc::now();
    println!(r#"echo "time={}" >> $GITHUB_OUTPUT"#, now.to_rfc3339());

    Ok(())
}
