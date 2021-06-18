<template>
  <v-container>
    <v-list-item-title v-if="penalty.kind == 'fee'">
    Fee
      <span v-if="penalty.fee.min == penalty.fee.max">of ${{penalty.fee.min/100}}</span>
      <span v-else>between ${{penalty.fee.min/100}} and ${{penalty.fee.max/100}}</span>
    </v-list-item-title>
    <v-list-item-title v-if="penalty.kind == 'fine'">
    Fine
      <span v-if="penalty.fine.min == penalty.fine.max">of ${{penalty.fine.min/100}}</span>
      <span v-else>between ${{penalty.fine.min/100}} and ${{penalty.fine.max/100}}</span>
    </v-list-item-title>
    <v-list-item-title v-if="penalty.kind == 'imprisonment'">
    Imprisonment of
      <span v-if="penalty.imprisonment.min == penalty.imprisonment.max">of ${{penalty.days.min}} days</span>
      <span v-else>between ${{penalty.imprisonment.min}} and ${{penalty.imprisonment.max}}</span>
    </v-list-item-title>
    <v-list-item-title v-if="penalty.kind == 'lose_right_to_drive_until_18'">
      Lose the right to drive until 18
    </v-list-item-title>
    <v-list-item-title v-if="penalty.kind == 'either'">
      <strong>Either one of</strong>
      <v-list-item two-line v-for="p in penalty.either" v-bind:key="JSON.stringify(p)">
        <penalty :penalty="p" />
      </v-list-item>
    </v-list-item-title>
  </v-container>
</template>
<script>
  export default {
    props: [ 'penalty' ],
    name: 'penalty'
  }
</script>
