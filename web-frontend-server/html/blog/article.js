// The rings and moving nodes take inspiration from ThreeUI's Structure Flow Orbital Sphere.
const orbitMotion = matchMedia("(any-hover: hover) and (any-pointer: fine) and (prefers-reduced-motion: no-preference)");

for (const visual of document.querySelectorAll("[data-orbit]")) {
    const frame = visual.querySelector(".visual-frame");

    function resetOrbit() {
        visual.style.removeProperty("--orbit-x");
        visual.style.removeProperty("--orbit-y");
    }

    frame.addEventListener("pointermove", (event) => {
        if (!orbitMotion.matches || event.pointerType === "touch") return;

        const bounds = frame.getBoundingClientRect();
        const x = (event.clientX - bounds.left) / bounds.width - 0.5;
        const y = (event.clientY - bounds.top) / bounds.height - 0.5;
        visual.style.setProperty("--orbit-x", `${x * 36}px`);
        visual.style.setProperty("--orbit-y", `${y * 28}px`);
    });

    frame.addEventListener("pointerleave", resetOrbit);
    frame.addEventListener("pointercancel", resetOrbit);
    orbitMotion.addEventListener("change", resetOrbit);
}

const demo = document.querySelector("[data-dtn]");

if (demo) {
    const send = demo.querySelector("[data-send]");
    const toggle = demo.querySelector("[data-link-toggle]");
    const queuedOutput = demo.querySelector("[data-queued]");
    const receivedOutput = demo.querySelector("[data-received]");
    const status = demo.querySelector("[data-status]");
    let connected = false;
    let queued = 0;
    let received = 0;

    send.addEventListener("click", () => {
        if (connected) {
            received += 1;
            receivedOutput.value = received;
            status.textContent = `Trạm mặt đất đã nhận bundle số ${received}.`;
        } else {
            queued += 1;
            queuedOutput.value = queued;
            status.textContent = `Vệ tinh đang giữ ${queued} bundle trong lúc mất liên lạc.`;
        }
    });

    toggle.addEventListener("click", () => {
        connected = !connected;
        demo.dataset.link = connected ? "on" : "off";
        toggle.textContent = connected ? "Ngắt liên kết" : "Khôi phục liên kết";

        if (connected) {
            status.textContent = queued
                ? `Đã khôi phục liên kết. Trạm mặt đất vừa nhận ${queued} bundle từ hàng đợi.`
                : "Đã khôi phục liên kết. Trạm mặt đất sẵn sàng nhận bundle.";
            received += queued;
            queued = 0;
            queuedOutput.value = queued;
            receivedOutput.value = received;
        } else {
            status.textContent = "Liên kết đến Trái Đất đang gián đoạn.";
        }
    });

    demo.querySelector(".demo-actions").hidden = false;
}
