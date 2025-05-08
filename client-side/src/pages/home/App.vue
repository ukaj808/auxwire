<script setup lang="ts">
</script>

<template>
  <div class="h-screen flex flex-col bg-white dark:bg-black dark:text-white">
    <nav class="flex-1 flex items-start justify-start">
      <a href="#" class="text-lg md:text-2xl p-4 md:p-8">Home</a>
      <a href=" #" class="text-lg md:text-2xl p-4 md:p-8">Privacy</a>
    </nav>
    <section class="flex-1 flex flex-col items-center justify-center">
      <h1 class="text-6xl md:text-9xl">auxwire</h1>
      <p class="text-lg md:text-4xl pb-4 md:pb-8 text-center">
        Take turns playing music with your friends
      </p>
      <form action="" method="post">
        <input type="submit" id="create-room" value="Create room"
          class="cursor-pointer text-lg md:text-4xl border-4 animate-(--animate-border-pulse-black) dark:animate-(--animate-border-pulse-white) rounded-lg bg-sky-500 text-white dark:text-white p-2 md:p-4">
      </form>
      <p class="text-lg md:text-2xl p-4 text-center">
        Click this button ^ and share the link
      </p>
    </section>
    <footer class="flex-1 flex flex-col items-center justify-center">
      <p>Powered by</p>
      <div>
        <a class="p-2" href="#">youtubedl</a>
        <a class="p-2" href="#">haskell</a>
      </div>
    </footer>
  </div>
</template>

<style></style>
