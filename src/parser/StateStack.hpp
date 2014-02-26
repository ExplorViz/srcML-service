/**
 * @file StateStack.hpp
 *
 * @copyright Copyright (C) 2004-2010  SDML (www.srcML.org)
 *
 * This file is part of the srcML Toolkit.
 *
 * The srcML Toolkit is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * The srcML Toolkit is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with the srcML Toolkit; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#ifndef STATESTACK_HPP
#define STATESTACK_HPP

#include <list>
#include <stack>
#include "TokenParser.hpp"
#include "srcMLException.hpp"

#include "State.hpp"

template <class Base>
class StateStack {
public:

    // token parser constructor
    StateStack(TokenParser* ptp)
        : parser(ptp), st()
    {}

    const Base& currentState() const {
        if (st.empty())
            throw Segmentation_Fault();

        return st.top();
    }

    Base& currentState() {
        if (st.empty())
            throw Segmentation_Fault();

        return st.top();
    }

    void startNewMode(const State::MODE_TYPE& m) {

        // prepare for the new stack
        st.push(Base(m, !empty() ? getTransparentMode() : 0, !empty() ? getMode() : 0));
    }

    void endCurrentMode() {

        if (st.size() == 1)
            throw Segmentation_Fault();

        popMode();
    }

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-parameter"

    void endCurrentMode(const State::MODE_TYPE& m) {

        if (st.size() <= 1)
            throw Segmentation_Fault();

        popMode();
    }

#pragma GCC diagnostic pop

    void endLastMode() {

        popMode();
    }

    State::MODE_TYPE getMode() const {

        return !st.empty() ? st.top().getMode() : 0;
    }

    State::MODE_TYPE getPrevMode() const {

        return !st.size() > 1 ? st.top().getMode() : 0;
    }

    State::MODE_TYPE getTransparentMode() const {

        return !st.empty() ? st.top().getTransparentMode() : 0;
    }

    void setMode(const State::MODE_TYPE& m) {
        if (st.empty())
            throw Segmentation_Fault();

        st.top().setMode(m);
    }

    void clearMode(const State::MODE_TYPE& m) {
        if (st.empty())
            throw Segmentation_Fault();

        st.top().clearMode(m);
    }

    void push(const State::MODE_TYPE& id) {
        if (st.empty())
            throw Segmentation_Fault();

        st.top().push((int) id);
    }

    void pop() {
        if (st.empty())
            throw Segmentation_Fault();

        st.top().pop();
    }

    // stack size
    int size() const {

        return (int)st.size();
    }

    // stack empty
    bool empty() const {

        return st.empty();
    }

    bool inMode(const State::MODE_TYPE& m) const {

        return !st.empty() ? st.top().inMode(m) : false;
    }

    bool inPrevMode(const State::MODE_TYPE& m) const {

        return st.size() > 1 ? st.top().inPrevMode(m) : false;
    }

    bool inTransparentMode(const State::MODE_TYPE& m) const {

        return !st.empty() ? st.top().inTransparentMode(m) : false;
    }

    // parentheses count
    int getParen() const {
        return !st.empty() ? st.top().getParen() : 0;
    }

    // increment the parentheses count
    void incParen() {
        if (st.empty())
            throw Segmentation_Fault();

        st.top().incParen();
    }

    // decrement the parentheses count
    void decParen() {
        if (st.empty())
            throw Segmentation_Fault();

        st.top().decParen();
    }

    // curly count
    int getCurly() const {
        return !st.empty() ? st.top().getCurly() : 0;
    }

    // increment the curly count
    void incCurly() {
        if (st.empty())
            throw Segmentation_Fault();

        st.top().incCurly();
    }

    // decrement the curly count
    void decCurly() {
        if (st.empty())
            throw Segmentation_Fault();

        st.top().decCurly();
    }

    // type count
    int getTypeCount() const {
        return !st.empty() ? st.top().getTypeCount() : 0;
    }

    // set type count
    void setTypeCount(int n) {
        if (st.empty())
            throw Segmentation_Fault();

        st.top().setTypeCount(n);
    }

    // increment the type count
    void incTypeCount() {
        if (st.empty())
            throw Segmentation_Fault();

        st.top().incTypeCount();
    }

    // decrement the type count
    void decTypeCount() {
        if (st.empty())
            throw Segmentation_Fault();

        st.top().decTypeCount();
    }

    // destructor
    ~StateStack() {

        // end all modes
        endAllModes();
    }

protected:

    // destructor
    void endAllModes() {

        // end all modes
        while (!st.empty()) {
            endCurrentMode(getMode());
        }
    }

    void popMode() {
        if (st.empty())
            throw Segmentation_Fault();

        // close all open elements
        while (!st.empty() && !st.top().openelements.empty()) {
            parser->endElement(st.top().openelements.top());
        }

        st.pop();
    }

private:
    TokenParser* parser;
    std::stack<Base> st;
};

#endif
