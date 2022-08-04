/*---
description: 
flags: [onlyStrict]
---*/

let triggered;

class SampleBehavior extends Behavior {
	sampleEvent(content) {
		triggered = content;
		return true;
	}
}

const one = new Content;
const two = new Content(null, {Behavior: SampleBehavior});
const three = new Content(null, {Behavior: SampleBehavior});

const container = new Column(null, {
	contents: [ one, two, three ],
	Behavior: SampleBehavior
});

container.firstThat("sampleEvent");
assert.sameValue(triggered, two, "sampleEvent should have been triggered by `two`");

container.remove(two);
triggered = undefined;
container.firstThat("sampleEvent");
assert.sameValue(triggered, three, "sampleEvent should have been triggered by `three`");

container.remove(three);
triggered = undefined;
container.firstThat("sampleEvent");
assert.sameValue(triggered, undefined, "sampleEvent should not have been triggered");

triggered = undefined;
container.firstThat("nonexistentEvent")
assert.sameValue(triggered, undefined, "nonexistentEvent should not have been triggered");