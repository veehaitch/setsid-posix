use std::os::unix::process::CommandExt;
use std::prelude::v1::Vec;
use std::process;
use std::result::Result::{Err, Ok};
use std::string::String;

use clap::{crate_authors, crate_description, crate_name, crate_version, App, Arg};
use nix::libc::{EXIT_FAILURE, EXIT_SUCCESS};
use nix::unistd::{getpgrp, getpid, setsid, ForkResult};

fn is_process_group_leader() -> bool {
    getpid() == getpgrp()
}

fn fork() {
    match unsafe { nix::unistd::fork() } {
        Ok(ForkResult::Parent { child: _child, .. }) => {
            process::exit(EXIT_SUCCESS);
        }
        Ok(ForkResult::Child) => {}
        Err(_) => {
            eprintln!("fork(2) failed");
            process::exit(EXIT_FAILURE);
        }
    }
}

fn create_new_session() {
    if setsid().is_err() {
        eprintln!("setsid(2) failed");
        process::exit(EXIT_FAILURE);
    }
}

struct Opts {
    fork: bool,
    program: String,
    arguments: Vec<String>,
}

fn parse_args() -> Opts {
    let matches = App::new(crate_name!())
        .version(crate_version!())
        .author(crate_authors!())
        .about(crate_description!())
        .arg(
            Arg::with_name("ctty")
                .help(
                    "Set the controlling terminal to the current one. \
                    Currently not implemented.",
                )
                .long("ctty")
                .short("c")
                .takes_value(false),
        )
        .arg(
            Arg::with_name("fork")
                .help("Always create a new process")
                .long("fork")
                .short("f")
                .takes_value(false),
        )
        .arg(
            Arg::with_name("wait")
                .help(
                    "Wait for the execution of the program to end, and return the exit value \
                    of this program as the return value of setsid",
                )
                .long("wait")
                .short("w")
                .takes_value(false),
        )
        .arg(
            Arg::with_name("program")
                .required(true)
                .help("The program to run in a new session"),
        )
        .arg(
            Arg::with_name("arguments")
                .help("The arguments to pass to `program`, if any")
                .multiple(true)
                .required(false),
        )
        .get_matches();

    if matches.is_present("wait") {
        eprintln!("The --wait flag is currently not implemented");
        process::exit(EXIT_FAILURE);
    }

    if matches.is_present("ctty") {
        eprintln!("The --ctty flag is currently not implemented");
        process::exit(EXIT_FAILURE);
    }
    
    Opts {
        fork: matches.is_present("fork"),
        program: matches.value_of("program").unwrap().to_string(),
        arguments: matches
            .values_of("arguments")
            .unwrap_or_default()
            .map(std::string::ToString::to_string)
            .collect(),
    }
}

fn main() {
    let opts = parse_args();

    if opts.fork || is_process_group_leader() {
        fork();
    }

    create_new_session();

    process::Command::new(opts.program)
        .args(opts.arguments)
        .exec();
}
