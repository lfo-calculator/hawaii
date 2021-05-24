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
        <v-form @submit.prevent="computeNeeds">
          <v-row>
            <v-spacer></v-spacer>
            <v-col cols="10">
              <v-autocomplete
                  v-model="charges"
                  :disabled="isUpdating"
                  :items="regulations"
                  :rules="chargeSelectorRules"
                  required
                  filled
                  chips
                  clearable
                  deletable-chips
                  multiple
                  color="primary"
                  label="Select one or more charges to evaluate"
                  item-text="regulation"
                  item-value="section"
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
                  <template
                    v-if="typeof data.item !== 'object'"
                  >
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
            <v-col cols="10">
              <v-spacer></v-spacer>
              <v-btn
                type="submit"
                color="primary"
              >
                Submit
              </v-btn>
              <v-spacer></v-spacer>
            </v-col>
            <v-spacer></v-spacer>
          </v-row>
        </v-form>
        <v-card
          class="mx-auto"
          max-width="600"
          tile
          v-if="relevant.length > 0"
        >
          <v-card-title>
            Relevant regulations:
          </v-card-title>
          <v-list-item two-line v-for="r in relevant" v-bind:key="r.charge">
            <v-list-item-content>
              <v-list-item-title>
                For {{ r.title }} <a target="_blank" :href="r.url">({{ r.charge }})</a>:
              </v-list-item-title>
              <v-list-item-subtitle>
                <span v-for="(s, i) in r.sections" v-bind:key="s.charge">
                  <span v-if="i != 0">, </span>
                  {{ s.charge }} <a target="_blank" :href="s.url">({{ s.title }})</a>
                </span>
              </v-list-item-subtitle>
            </v-list-item-content>
          </v-list-item>
        </v-card>
        <v-spacer />
        <v-card
          class="mx-auto"
          max-width="600"
          tile
          v-if="Object.keys(needs).length > 0"
        >
          <v-card-title>
            We need more information!
          </v-card-title>
          <v-form>
            <v-text-field
              value=""
              label="Age of the defendant"
              v-if="needs.age"
            ></v-text-field>
            <span v-if="needs.priors">We also need prior offenses</span>
          </v-form>
        </v-card>
      </v-container>
    </v-main>
  </v-app>
</template>

<script>
import axios from 'axios';
import lfo from 'hawaii-lfo';

export default {
  name: 'App',
  data() {
    return {
      autoUpdate: true,
      charges: [],
      isUpdating: false,
      regulations: [],
      relevant: [
        // { charge: "test-charge", sections: [ "test-section1", "test-section2" ]}
      ],
      needs: {},
      chargeSelectorRules: [
        value => !!value || 'Please select at least one regulation'
      ]
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
      const index = this.regulations.indexOf(item.regulation)
      if (index >= 0)
        this.regulations.splice(index, 1)
    },
    computeNeeds() {
      this.relevant = [];
      this.needs = {};
      this.charges.forEach(c => {
        let r = lfo.relevant(c);
        this.relevant.push(r);
        r.needs.forEach(x => (this.needs[x] = true));
      });
    },
  },
}
</script>
