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
        <v-row>
          <v-row v-if="relevant.length > 0">
          Regulations relevant for these violations:
          </v-row>
          <v-row v-for="r in relevant" v-bind:key="r.charge">
            For {{ r.charge }}:
            <span v-for="s in r.sections" v-bind:key="s">
              {{ s }}
            </span>
          </v-row>
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
      charges: [],
      isUpdating: false,
      regulations: [],
      relevant: [{ charge: "test-charge", sections: [ "test-section1",
      "test-section2" ]}],
      needs: {
        age: false,
        priors: false,
        is_construction: false
      },
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
      this.charges.forEach(c => {
        let { sections, needs } = lfo.relevant(c);
        this.relevant.push({
          charge: c,
          sections: sections
        });
        needs.forEach(x => (needs[x] = true));
      });
    },
  },
}
</script>
