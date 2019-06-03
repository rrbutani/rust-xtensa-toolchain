workflow "Build the container, tag it, and push to Docker Hub" {
  resolves = ["Build container: Stage 1", "Build container: Stage 2", "Log into Docker Hub", "Tag toolchain container", "Push to Docker Hub"]
  on = "push"
}

action "Log into Docker Hub" {
  uses = "actions/docker/login@8cdf801b322af5f369e00d85e9cf3a7122f49108"
  secrets = ["DOCKER_USERNAME", "DOCKER_PASSWORD"]
}

action "Build container: Stage 1" {
  uses = "actions/docker/cli@8cdf801b322af5f369e00d85e9cf3a7122f49108"
  needs = ["Log into Docker Hub"]
  args = "build --target build ."
}

action "Build container: Stage 2" {
  uses = "actions/docker/cli@8cdf801b322af5f369e00d85e9cf3a7122f49108"
  needs = ["Build container: Stage 1"]
  args = "build -t rust-xtensa ."
}

action "Tag toolchain container" {
  uses = "actions/docker/tag@8cdf801b322af5f369e00d85e9cf3a7122f49108"
  needs = ["Build container: Stage 2"]
  args = "rust-xtensa rrbutani/rust-xtensa"
}

action "Tag toolchain container with version" {
  uses = "docker://rrbutani/docker-version-tag"
  needs = ["Build container: Stage 2"]
  args = "rust-xtensa rrbutani/rust-xtensa Dockerfile"
}

action "Push to Docker Hub" {
  uses = "actions/docker/cli@8cdf801b322af5f369e00d85e9cf3a7122f49108"
  needs = ["Tag toolchain container", "Tag toolchain container with version"]
  args = "push rrbutani/rust-xtensa"
}
