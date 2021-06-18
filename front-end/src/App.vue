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
        <v-stepper v-model="e1">
          <v-stepper-header>
            <v-stepper-step
              :complete="e1 > 1"
              step="1"
            >
              Charges
            </v-stepper-step>

            <v-divider></v-divider>

            <v-stepper-step
              :complete="e1 > 2"
              step="2"
            >
              Relevant information
            </v-stepper-step>

            <v-divider></v-divider>

            <v-stepper-step step="3">
              Penalties
            </v-stepper-step>
          </v-stepper-header>

          <v-stepper-items>
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
                  <v-list-item-content>
                    <v-list-item-title v-html="data.item.regulation"></v-list-item-title>
                    <v-list-item-subtitle v-html="data.item.section"></v-list-item-subtitle>
                  </v-list-item-content>
                </template>
              </v-autocomplete>
              <v-btn
                color="primary"
                @click="e1 = 2, computeNeeds()"
              >
                Continue
              </v-btn>
            </v-stepper-content>

            <v-stepper-content step="2">
              <v-container>
                <v-form v-if="relevant != null">
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
                      v-model="relevant.needs.age"
                      value=""
                      label="Age of the defendant"
                      v-if="'age' in relevant.needs"
                    ></v-text-field>
                  </v-card>
                  <v-card
                    class="mx-auto"
                    max-width="1000"
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
                            v-model="relevant_s.needs.two_priors_past_five_years"
                            label="Two identical offenses within past five years"
                          >
                          </v-checkbox>
                        </v-list-item-subtitle>
                      </v-list-item-content>
                    </v-list-item>
                  </v-card>
                </v-form>
              </v-container>


              <v-btn
                color="primary"
                @click="e1 = 3, computePenalties()"
              >
                Continue
              </v-btn>

              <v-btn text>
                Cancel
              </v-btn>
            </v-stepper-content>

            <v-stepper-content step="3">
              <v-container v-if="penalties != null">
                <v-card
                  class="mx-auto"
                  max-width="1000"
                  tile
                  v-for="v in penalties"
                  v-bind:key="v.violation"
                >
                  <v-card-title>
                    Violation {{ v.title }} (<a target="_blank" :href="v.url">{{ v.violation }}</a>)
                  </v-card-title>
                  <v-list-item two-line v-for="p in v.penalties" v-bind:key="p.regulation">
                    <v-list-item-content>
                      <v-list-item-title>
                        {{ p.title }} (<a target="_blank" :href="p.url">{{ p.regulation }}</a>)
                      </v-list-item-title>
                      <v-subheader>Applicable penalties:</v-subheader>
                      <v-list-item two-line v-for="p_ in p.penalties" v-bind:key="JSON.stringify(p_)">
                        <v-list-item-title v-if="p_.kind == 'fee'">
                        Fee
                          <span v-if="p_.fee.min == p_.fee.max">of ${{p_.fee.min/100}}</span>
                          <span v-else>between ${{p_.fee.min/100}} and ${{p_.fee.max/100}}</span>
                        </v-list-item-title>
                        <v-list-item-title v-if="p_.kind == 'fine'">
                        Fine
                          <span v-if="p_.fine.min == p_.fine.max">of ${{p_.fine.min/100}}</span>
                          <span v-else>between ${{p_.fine.min/100}} and ${{p_.fine.max/100}}</span>
                        </v-list-item-title>
                        <v-list-item-title v-if="p_.kind == 'imprisonment'">
                        Imprisonment of
                          <span v-if="p_.imprisonment.min == p_.imprisonment.max">of ${{p_.days.min}} days</span>
                          <span v-else>between ${{p_.imprisonment.min}} and ${{p_.imprisonment.max}}</span>
                        </v-list-item-title>
                      </v-list-item>
                    </v-list-item-content>
                  </v-list-item>
                </v-card>


                <v-btn
                  color="primary"
                  @click="e1 = 1"
                >
                  Continue
                </v-btn>

                <v-btn text>
                  Cancel
                </v-btn>
              </v-container>
            </v-stepper-content>
          </v-stepper-items>
        </v-stepper>
      </v-container>
    </v-main>
  </v-app>
</template>

<script>
import json from '../../data/hawaii-regulations.json'
import lfo from 'hawaii-lfo';

export default {
  name: 'App',
  data() {
    return {
      autoUpdate: true,
      charges: [],
      isUpdating: false,
      regulations: json.regulations.filter(x => x.violation),
      relevant: null,
      penalties: null,
      needs: {},
      e1: 1,
      chargeSelectorRules: [
        value => !!value || 'Please select at least one regulation'
      ]
    }
  },
  async created() {
    try {
      // nothing here anymore
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
    },
    computePenalties() {
      let p = lfo.computePenalties(this.relevant);
      console.log(p);
      this.penalties = p;
    }
  },
}
</script>
