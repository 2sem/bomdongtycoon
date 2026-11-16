import ProjectDescription

let tuist = Tuist(
    fullHandle: "gamehelper/bomdongtycoon",
    // Without this, `tuist generate` fails with "Token for Tuist was not found" on any machine
    // that has not run `tuist auth login`, including the deploy workflow.
    project: .tuist(generationOptions: .options(optionalAuthentication: true))
)
