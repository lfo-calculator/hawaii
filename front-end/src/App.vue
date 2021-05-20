<template>
  <v-app>
    <v-app-bar
      app
      color=indigo
      dark
    >
      <v-avatar :tile="true">
    <img :src="require('@/assets/HI_seal.png')" alt="Hawaii State Seal">
  </v-avatar>
      <div class="d-flex align-center">
      <v-toolbar-title>Hawaii LFO Calculator</v-toolbar-title>
      </div>

      <v-spacer></v-spacer>

      <v-btn
        href="https://github.com/lfo-calculator/hawaii"
        target="_blank"
        text
      >
        <span class="mr-2">Github repo</span>
        <v-icon>mdi-open-in-new</v-icon>
      </v-btn>
    </v-app-bar>
<v-main>
 <v-container>
    <v-row class="text-center">
      <v-col cols="12">
        <h1 class="display-1 font-weight-bold mb-3">
          Welcome to the Hawaii LFO Calculator
        </h1>
     </v-col>
    </v-row>
    <v-row>
      <v-spacer></v-spacer>
      <v-col cols="10">
          <v-autocomplete
              v-model="charges"
              :disabled="isUpdating"
              :items="regulations"
              filled
              chips
              color="blue-grey lighten-2"
              label="Select one or more charges to evaluate"
              item-text="regulation"
              item-value="section"
              multiple
            >
              <template v-slot:selection="data">
                <v-chip
                  v-bind="data.attrs"
                  :input-value="data.selected"
                  close
                  @click="data.select"
                  @click:close="remove(data.item)"
                >
                  {{ data.item.regulation }}
                </v-chip>
              </template>
              <template v-slot:item="data">
                <template v-if="typeof data.item !== 'object'">
                  <v-list-item-content v-text="data.item"></v-list-item-content>
                </template>
                <template v-else>
                  <v-list-item-content>
                    <v-list-item-title v-html="data.item.regulation"></v-list-item-title>
                    <v-list-item-subtitle v-html="data.item.section"></v-list-item-subtitle>
                  </v-list-item-content>
                </template>
              </template>
            </v-autocomplete>
          </v-col>
         <v-spacer></v-spacer>

        </v-row>

        <v-row>
          <v-spacer></v-spacer>
          <v-col cols="4">
            <v-btn type="submit" color="primary">
              Submit
            </v-btn>
          </v-col>
          <v-spacer></v-spacer>
      </v-row>
  </v-container>
</v-main>
  </v-app>
</template>

<script>
import axios from 'axios';

export default {
  name: 'App',
  data() {
    return {
      autoUpdate: true,
      charges: [],
      isUpdating: false,
      regulations: []
    }
  },
  async created() {
    try {
      const res = await axios.get(`http://localhost:3000/regulations?violation=true`)

      this.regulations = res.data;
    } catch(e) {
      console.error(e)
    }
  },
      watch: {
      isUpdating (val) {
        if (val) {
          setTimeout(() => (this.isUpdating = false), 3000)
        }
      },
    },

    methods: {
        remove (item) {
        const index = this.charges.indexOf(item.regulation)
        if (index >= 0) this.charges.splice(index, 1)
      },
},
}
</script>
