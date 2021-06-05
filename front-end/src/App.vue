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
            <div>
              <v-stepper
                v-model="el"
                alt-labels
                class="mt-12"
              >
                <v-stepper-header>
                  <v-stepper-step 
                    step="1"
                    :complete="el > 1"
                  >
                    Submit charges
                  </v-stepper-step>

                  <v-divider></v-divider>

                  <v-stepper-step 
                    align="center" 
                    step="2"
                    :complete="el > 2"
                  >
                    Additional info
                  </v-stepper-step>

                  <v-divider></v-divider>

                  <v-stepper-step 
                    step="3"
                  >
                    Sentencing 
                  </v-stepper-step>
                </v-stepper-header>
                <v-stepper-content step="1">
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
                    <v-spacer></v-spacer>
                    <v-btn
                      color="primary"
                      @click="el = 2"
                    >
                      Continue
                    </v-btn>
                        <v-spacer></v-spacer>
                </v-stepper-content>
                <v-stepper-content
                  step="2"
                >
                  <v-container v-if="relevant != null">
          <v-card
            class="mx-auto"
            max-width="1000"
            tile
            v-if="Object.keys(relevant.needs).length > 0"
          >
            <v-card-title>
              General-purpose information required:
            </v-card-title>
              <v-text-field
                value=""
                label="Age of the defendant"
                v-if="'age' in relevant.needs"
              ></v-text-field>
          </v-card>
          <v-card
            class="mx-auto"
            tile
            v-for="(s, section) in relevant.contextual"
            v-bind:key="section"
          >
            <v-card-title>
              {{ s.title }} (<a target="_blank" :href="s.url">{{ section }}</a>)
            </v-card-title>
            <v-subheader>Relevant regulations:</v-subheader>
              <v-list-item two-line v-for="(relevant_s, relevant_section) in s.relevant" v-bind:key="relevant_section">
                <v-list-item-content>
                  <v-list-item-title>
                    {{ relevant_s.title }} (<a target="_blank" :href="relevant_s.url">{{ relevant_section }}</a>)
                  </v-list-item-title>
                  <v-list-item-subtitle v-if="Object.keys(relevant_s.needs).length > 0">
                    <v-checkbox v-if="'two_priors_past_five_years' in relevant_s.needs"
                      label="Two identical offenses within past five years"
                    >
                    </v-checkbox>
                  </v-list-item-subtitle>
                </v-list-item-content>
              </v-list-item>
          </v-card>
        </v-container>
                </v-stepper-content>
              </v-stepper>
              
            </div>
           </v-col>
        </v-row>
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
      el: 1,
      charges: [],
      isUpdating: false,
      regulations: [],
      relevant: null,
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
      let r = lfo.relevant(this.charges);
      console.log(r);
      this.relevant = r;
      return;
    },
  },
}
</script>
