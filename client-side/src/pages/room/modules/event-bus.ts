export class EventBus<K, V> {

    public subscriptions: Map<K, ((event: V) => void)[]> = new Map();

    public subscribe(msgType: K, callback: (event: V) => void) {
        if (!this.subscriptions.has(msgType)) {
            this.subscriptions.set(msgType, []);
        }
        if (this.subscriptions.get(msgType)?.includes(callback)) {
            return;
        }
        this.subscriptions.get(msgType)!.push(callback);
    }

    public unsubscribe(eventType: K, callback: (event: V) => void) {
        if (!this.subscriptions.has(eventType)) {
            return;
        }
        const callbacks = this.subscriptions.get(eventType)!;
        const index = callbacks.indexOf(callback);
        if (index >= 0) {
            callbacks.splice(index, 1);
        }
    }

    public publish(msgType: K, event: V) {
        const callbacks = this.subscriptions.get(msgType);
        if (callbacks) {
            callbacks.forEach(callback => callback(event));
        }
    }

}