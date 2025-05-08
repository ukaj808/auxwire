<script lang="ts">
import { RestClient } from "../modules/rest-client";
import { RoomMessageListener } from "../modules/room-message-listener";
import {
  type ServerWelcomeCommand,
  type CountingDownEvent,
  type UserEnterEvent,
  type UserLeftEvent,
} from "../modules/interface";
import { MutableStyleSheet } from "../modules/stylesheet-manipulations";
import { type ResponsiveQueueAnimationManager, responsiveQueueAnimationManager } from "../modules/responsive-queue-animation";

// Animations in this class are based on the following recommendations from the W3C for
// achieving animations whose effects should b applied indefinitely:
// https://drafts.csswg.org/web-animations-1/#example-0307c584
export class UserQueueElement {
  private userSectionEl: HTMLElement;
  private mobileStyleSheet: MutableStyleSheet;
  private desktopStyleSheet: MutableStyleSheet;
  private roomMessageListener: RoomMessageListener;
  private offset = 20;
  private mediaQueryList: MediaQueryList;
  private runningAnimations: Animation[] = [];
  private usersAnimationManager: ResponsiveQueueAnimationManager;

  constructor(
    roomMessageListener: RoomMessageListener,
    restClient: RestClient,
    mobileStyleSheet: MutableStyleSheet,
    desktopStyleSheet: MutableStyleSheet
  ) {
    const userSectionEl = document.getElementById("user-section");
    if (!userSectionEl) throw new Error("No user section element found");
    this.userSectionEl = userSectionEl;

    this.userSectionEl.addEventListener("click", () => {
      this.usersAnimationManager.cycle();
    });

    this.mobileStyleSheet = mobileStyleSheet;
    this.desktopStyleSheet = desktopStyleSheet;

    this.roomMessageListener = roomMessageListener;
    this.roomMessageListener.subscribe("ServerWelcomeCommand", (data) => {
      const welcomeCommand = data as ServerWelcomeCommand;
      this.addNewUserToLine(
        welcomeCommand.userId,
        welcomeCommand.userName,
        welcomeCommand.hexColor
      );
    });
    this.roomMessageListener.subscribe("UserEnterEvent", (data) => {
      const userEnterEvent = data as UserEnterEvent;
      this.addNewUserToLine(
        userEnterEvent.userId,
        userEnterEvent.userName,
        userEnterEvent.hexColor
      );
    });
    this.roomMessageListener.subscribe("UserLeftEvent", (data) => {
      const userLeftEvent = data as UserLeftEvent;
      this.removeUserFromLine(userLeftEvent.userId);
    });
    this.roomMessageListener.subscribe("NextInQueueEvent", (data) => {
      // this.nextInLine();
    });

    this.mediaQueryList = window.matchMedia(
      "screen and (min-width:0px) and (max-width:1025px)"
    );
    this.mediaQueryList.addEventListener("change", (e) => {
      this.runningAnimations.forEach((a) => a.finish());
    });


    this.usersAnimationManager = responsiveQueueAnimationManager({
      queue: this.userSectionEl,
      childElementType: "div",
      childElementClassName: "user",
      styleOptionsArr: [
        {
          orientation: "horizontal",
          spaceBetweenElements: -20,
          elementWidth: 40,
          elementHeight: -1,
          startingTailPosition: 0,
          stylesheet: this.mobileStyleSheet,
          media: window.matchMedia(
            "screen and (min-width:0px) and (max-width:1025px)"),
        },
        {
          orientation: "vertical",
          spaceBetweenElements: 10,
          elementHeight: 100,
          elementWidth: -1,
          startingTailPosition: 10,
          stylesheet: this.desktopStyleSheet,
          media: window.matchMedia("screen and (min-width:1025px)")
        },
      ],
    })

    const stateAttribute = userSectionEl.getAttribute("data-og-state");
    if (!stateAttribute) throw new Error("No state attribute found");
  }

  public addNewUserToLine(userId: string, userName: string, hexColor: string) {
    const styles = new Map<string, string>([
      ["background-color", hexColor],
    ]);
    this.usersAnimationManager.enter(userId, styles);
  }

  public removeUserFromLine(userId: string) {
    this.usersAnimationManager.leave(userId);
  }

  // Should be run on nextInQueue event
  /*
private nextInLine() {
if (this.userSectionEl.childElementCount < 2) return;
if (this.userSectionEl.firstElementChild === null) return;
if (this.userSectionEl.lastElementChild === null) return;

const moveToEndAndSomeAnimation = this.userSectionEl.firstElementChild.animate([
{
left: this.endPositionPx + 100 + 'px',
}
],
{
duration: 1000,
fill: 'forwards'
}); 
const user = document.getElementById(userId);
if (!user) throw new Error('No user element found');
const mobileRule = `#${userId} { z-index: ${position.zIndex}; left: ${position.left}; }`;
const mobileRuleIndex = this.mobileStyleSheet.cssRules.length;
this.mobileStyleSheet.insertRule(mobileRule, mobileRuleIndex);
user.setAttribute('data-mobile-rule-index', mobileRuleIndex.toString());
moveToEndAndSomeAnimation.pause();

const moveToLastPlaceAnimation = this.userSectionEl.firstElementChild.animate([
{
left: this.endPositionPx + 'px',
}
],
{
duration: 1000,
fill: 'forwards'
});
moveToLastPlaceAnimation.pause();

const oneUpAnimations: Animation[] = [];
for (let i = 1; i < this.userSectionEl.childElementCount; i++) {
const u = this.userSectionEl.children[i] as HTMLDivElement;
const upOneAnimation = u.animate([
{
left: parseInt(u.style.left) - this.offset + 'px',
}
],
{
duration: 1000,
fill: 'forwards'
});
upOneAnimation.pause();
oneUpAnimations.push(upOneAnimation);
}

// Play all animations
moveToEndAndSomeAnimation.play();
oneUpAnimations.forEach(a => a.play());
Promise.all([moveToEndAndSomeAnimation.finished, ...oneUpAnimations.map(a => a.finished)])
.then(() => {

oneUpAnimations.forEach(a => { a.commitStyles(); a.cancel(); });
moveToEndAndSomeAnimation.commitStyles();
moveToEndAndSomeAnimation.cancel();
const head = this.userSectionEl.firstElementChild as HTMLDivElement;

// at this point, the left property should have been updated through the commitStyles() call
// but we still need to update the zIndex
for (let i = 1; i < this.userSectionEl.childElementCount; i++) {
const u = this.userSectionEl.children[i] as HTMLDivElement;
u.style.zIndex = (parseInt(u.style.zIndex) + 1).toString();
}

head.remove();
this.userSectionEl.appendChild(head);
head.style.zIndex = '0';

moveToLastPlaceAnimation.play();
moveToLastPlaceAnimation.finished.then(() => {
moveToLastPlaceAnimation.commitStyles();
moveToLastPlaceAnimation.cancel();
});
});
};
*/
}
</script>

<template>
</template>

<style scoped>
</style>
