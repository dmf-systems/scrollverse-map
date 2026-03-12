# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## Identity layer
`packages/identity` provides DMF7 DID support (`did:dmf7:` prefix) for unique node and agent identities with signature verification.

```ts
import { IdentityRegistry, signIdentityPayload } from './packages/identity/identity-registry';
import { createNodeIdentity } from './packages/identity/node-identity';

const registry = new IdentityRegistry();
const node = registry.register(createNodeIdentity());

const payload = { hello: 'dmf7' };
const signature = signIdentityPayload(node, payload);

registry.verify(node.did, payload, signature); // true
```
