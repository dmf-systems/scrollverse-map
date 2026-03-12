# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 stack orchestration

Run the automation helper to install Docker Compose, generate the stack file, start services, and register the `dmf7-stack` control binary:

```bash
sudo ./scripts/dmf7_stack_compose_setup.sh
```

Afterward, manage the stack with:

```bash
dmf7-stack {start|stop|restart|status|logs}
```
