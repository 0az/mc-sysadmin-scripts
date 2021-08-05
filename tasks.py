from __future__ import annotations

from invoke import Collection, Task, task

import os
import shlex

REPO_PREFIX = 'docker.io/afzhou/'

SPEC = {
    'paper': 'paper.Dockerfile',
    'velocity': 'velocity.Dockerfile',
}

DRY_RUN = os.getenv('DRY_RUN', '').lower() in ('1', 'yes', 'y', 'true', 't')
TAG_SUFFIX = os.getenv('SUFFIX', '')
IMAGE_VERSION = os.getenv('VERSION', 'latest')

def _docker_build(file: 'PathLike', target: str, label: str, tag: str) -> str:
    if TAG_SUFFIX:
        tag = tag + TAG_SUFFIX
    return f'docker build -f {file} --target {target} --tag {REPO_PREFIX}{label}:{tag} .'


def _docker_run(name: str, tag: str, command: list[str] = None) -> str:
    if TAG_SUFFIX:
        tag = tag + TAG_SUFFIX
    tag = f':{tag}' if tag else ''
    cmd = shlex.join(command) if command else ''
    return f'docker run -it --rm {REPO_PREFIX}{name}{tag} {cmd}'


def _docker_push(name: str, tag: str) -> str:
    if TAG_SUFFIX:
        tag = tag + TAG_SUFFIX
    return f'docker push {REPO_PREFIX}{name}:{tag}'


def build_task(label: str, stage: str, deps: list = None):
    file = f'{label}.Dockerfile'
    name = f'{label}-{stage}'

    @task(name=name, pre=deps)
    def _inner(c):
        print(f'Docker: Building {label}, stage :{stage})')
        cmd = _docker_build(file, stage, label, f'{IMAGE_VERSION}-{stage}')
        if DRY_RUN:
            print(cmd)
        else:
            c.run(cmd, pty=True)

    return _inner


def run_task(label: str, tag: str, command: list[str]):
    name = label
    if tag != 'artifact':
        name += '-tag'
    if command and command[0] == 'sh':
        name += '-shell'
    tag = f'{IMAGE_VERSION}-{tag}'

    @task(name=name)
    def _inner(c):
        cmd = _docker_run(label, tag, command)
        if DRY_RUN:
            print(cmd)
            return
        if pid := os.fork():
            os.wait()
        else:
            args = shlex.split(cmd)
            os.execvp(args[0], args)

    return _inner


_docker_tasks = []
_artifact_tasks = []
_run_tasks = []

for label in ('paper', 'velocity'):
    for stage in ('build', 'artifact'):
        deps = [globals()[f'{label}_build']] if stage == 'artifact' else None
        _task = build_task(
            label,
            stage,
            deps=deps,
        )
        _docker_tasks.append(_task)
        if stage == 'artifact':
            _artifact_tasks.append(_task)
        globals()[f'{label}_{stage}'] = _task

        for command in ('default', 'shell'):
            if command == 'default':
                cmd = []
            else:
                cmd = ['sh']
            _task = run_task(label, stage, cmd)
            _run_tasks.append(_task)
            globals()[f'run_{label}_{stage}'] = _task


@task(*_artifact_tasks)
def build(_c):
    pass


@task
def push(c):
    print('Docker: Pushing images')
    for label in ('paper', 'velocity'):
        for stage in ('build', 'artifact'):
            cmd = _docker_push(label, f'{IMAGE_VERSION}-{stage}')
            if DRY_RUN:
                print(cmd)
            else:
                c.run(cmd, pty=True)
    print('Docker: Done pushing!')


docker_ns = Collection('docker')
for t in _docker_tasks:
    docker_ns.add_task(t)
docker_run_ns = Collection('run')
for t in _run_tasks:
    docker_run_ns.add_task(t)
docker_ns.add_collection(docker_run_ns)

ns = Collection()  # noqa: invalid-name
ns.add_collection(docker_ns)
ns.add_task(build)
ns.add_task(push)
