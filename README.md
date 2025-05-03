# Hello World GitHub Action (Docker)

This action prints "Hello World" or "Hello" + the name of a person to greet to the log.

## Inputs

### `greetee`

**Required** The name of the person to greet. Default `"World"`.

## Outputs

### `time`

The time we greeted you.

## Example usage

```yaml
on: [push]

jobs:
  hello_world_job:
    runs-on: ubuntu-latest
    name: A job to say hello
    steps:
    - name: Hello world action step
      id: hello # for use in step below
      uses: asaaki/hello-world-docker-action@v0
      with:
        greetee: 'Happy User'
    - name: Get the output time
      run: echo "The time was ${{ steps.hello.outputs.time }}"
```

Guide:
<https://docs.github.com/en/actions/creating-actions/creating-a-docker-container-action>
