// Removes YouTube ads, which network rules cannot block because YouTube serves
// them from its own domains. Three parts:
//   1. CSS hides ad slots in feeds, search results and the watch page.
//   2. While the player is showing an ad, mute it, fast-forward it and press
//      Skip as soon as the button appears.
//   3. Dismiss the "ad blockers are not allowed" dialog and resume playback.
(() => {
    "use strict";

    const HIDDEN_SELECTORS = [
        "#masthead-ad",
        "#player-ads",
        "ytd-ad-slot-renderer",
        "ytd-in-feed-ad-layout-renderer",
        "ytd-banner-promo-renderer",
        "ytd-statement-banner-renderer",
        "ytd-promoted-sparkles-web-renderer",
        "ytd-companion-slot-renderer",
        "ytd-player-legacy-desktop-watch-ads-renderer",
        "ytd-rich-item-renderer:has(ytd-ad-slot-renderer)",
        "ytd-engagement-panel-section-list-renderer[target-id='engagement-panel-ads']",
        "yt-mealbar-promo-renderer",
        "tp-yt-paper-dialog:has(yt-mealbar-promo-renderer)",
        ".ytp-ad-overlay-container",
        ".ytp-ad-image-overlay",
        // m.youtube.com
        "ad-slot-renderer",
        "ytm-companion-ad-renderer",
        "ytm-promoted-sparkles-web-renderer",
        "ytm-promoted-video-renderer",
    ];

    const SKIP_BUTTONS = [
        ".ytp-skip-ad-button",
        ".ytp-ad-skip-button",
        ".ytp-ad-skip-button-modern",
        ".ytp-ad-skip-button-container button",
    ].join(",");

    function injectStyles() {
        const style = document.createElement("style");
        style.id = "hush-youtube";
        style.textContent = `${HIDDEN_SELECTORS.join(",\n")} { display: none !important; }`;
        (document.head || document.documentElement).appendChild(style);
    }

    // Restored once the ad finishes, so the user's own mute setting survives.
    let adState = null;

    function handleVideoAd() {
        const player = document.querySelector(".html5-video-player");
        const video = player && player.querySelector("video");
        if (!video) return;

        const adShowing = player.classList.contains("ad-showing") || player.classList.contains("ad-interrupting");
        if (adShowing) {
            if (!adState) {
                adState = { muted: video.muted };
            }
            video.muted = true;
            video.playbackRate = 16;
            if (Number.isFinite(video.duration) && video.duration > 0 && video.currentTime < video.duration - 0.1) {
                video.currentTime = video.duration - 0.1;
            }
            const skip = document.querySelector(SKIP_BUTTONS);
            if (skip) skip.click();
        } else if (adState) {
            video.muted = adState.muted;
            video.playbackRate = 1;
            adState = null;
            if (video.paused && video.currentTime < 1) {
                video.play().catch(() => {});
            }
        }
    }

    function dismissEnforcementDialog() {
        const message = document.querySelector("ytd-enforcement-message-view-model");
        if (!message) return;
        const dialog = message.closest("tp-yt-paper-dialog") || message;
        dialog.remove();
        document.querySelectorAll("tp-yt-iron-overlay-backdrop").forEach((el) => el.remove());
        const video = document.querySelector("video.html5-main-video");
        if (video && video.paused) {
            video.play().catch(() => {});
        }
    }

    // YouTube mutates the DOM constantly; coalesce work to once per frame.
    let scheduled = false;
    function onMutation() {
        if (scheduled) return;
        scheduled = true;
        requestAnimationFrame(() => {
            scheduled = false;
            handleVideoAd();
            dismissEnforcementDialog();
        });
    }

    injectStyles();
    new MutationObserver(onMutation).observe(document.documentElement, {
        childList: true,
        subtree: true,
        attributes: true,
        attributeFilter: ["class"],
    });
})();
