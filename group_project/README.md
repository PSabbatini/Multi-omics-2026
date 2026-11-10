# Group project

The schedule, the sub-question menus and the check-in cards are on the
[Group Project page](https://elsherbini.github.io/data-science-for-biology/materials/2-workshop2/7-group-project/)
of the workshop website. This file covers what happens in your Codespace.

Everything you make for the group project goes in this folder. Pi writes the
`.qmd` files and renders them. To read one, open the `.qmd` and click the
**Preview** button at the top right of the editor (or press `Ctrl+Shift+K`).
The report opens in a pane next to your code and updates when the file changes.

## Your model

On Wednesday, one partner stays on the default, `z-ai/glm-5.3-flash`, and the
other types `/model` in Pi and picks `z-ai/glm-5.3`. On Thursday you swap.
Pi remembers the model you picked, so check which one you are on when you start
it in the morning.

Your spending is on your [OpenRouter activity page](https://openrouter.ai/activity).

## First: the QC report

Copy this into Pi, with your study's letter:

```
Make group_project/01-qc.qmd that checks the quality of the Study A data
before we analyse it. Render it.
```

## Then: your sub-question

Ask for one `.qmd` per idea, numbered in the order you make them, such as
`02-community-shift.qmd`. Some ways to ask:

```
Make group_project/02-community-shift.qmd that asks whether the vaginal
community changed from pre to post in Study A, and whether the change differs
by arm. Render it.
```

```
You used Bray-Curtis distance. What else could you have used, and would it
change the answer? Add the other one to the document so I can compare them.
```

```
I don't understand what PERMANOVA is testing here. Explain it in a few
sentences, and give me a link to a paper or documentation page I can read
myself.
```

```
Save the figure from the second chunk as a PNG in group_project/figures/.
```

To get a figure into your group's Google Slides deck, right-click it in the
file list on the left and choose **Download**.

## End of each morning

Before lunch, write a few lines at the top of your `.qmd` saying where you got
to and what you were about to try. You and Pi both start Thursday from that.
